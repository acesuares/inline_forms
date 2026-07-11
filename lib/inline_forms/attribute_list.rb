# -*- encoding : utf-8 -*-

module InlineForms
  # A structured, mutable view over a model's `inline_forms_attribute_list`.
  #
  # The list has always been (and remains) an Array of positional rows:
  #
  #   [ :name,      :text_field ]
  #   [ :priority,  :dropdown_with_values, { 1 => 'low', 2 => 'high' } ]
  #   [ :priority2, :dropdown_with_values, { 1 => 'low', 2 => 'high' }, [ 2 ] ]
  #
  # where index 0 is the attribute, index 1 the form element, index 2 an
  # optional values hash, and index 3 an optional disabled-options array.
  #
  # Every downstream consumer relies on that shape: the views destructure
  # `|attribute, form_element|`, and the helpers/validator fetch the values
  # hash positionally with `list.assoc(attr)[2]`. `AttributeList` therefore
  # *subclasses Array* and keeps rows as plain arrays — so an `AttributeList`
  # IS a valid attribute list everywhere the old literal array was, with zero
  # migration. What it adds is a small DSL/API for building and editing the
  # list procedurally (append / insert / remove / move / replace) instead of
  # hand-editing an array literal or regex-surgery on model source.
  #
  # Build fresh:
  #
  #   InlineForms::AttributeList.build do
  #     header :basics
  #     field  :name,     :text_field
  #     field  :priority, :dropdown_with_values, values: { 1 => 'low', 2 => 'high' }
  #     info   :created_at, :updated_at
  #   end
  #
  # Wrap and edit an existing list (what generators / the staging pipeline do):
  #
  #   InlineForms::AttributeList.wrap(model.inline_forms_attribute_list)
  #     .insert_after(:name, :internal_note, :text_field)
  #     .remove(:legacy_field)
  #
  # Mutating methods return self, so calls chain.
  class AttributeList < Array
    # Build a list from a block evaluated in the list's context.
    def self.build(&block)
      list = new
      list.instance_eval(&block) if block
      list
    end

    # Return `rows` as an AttributeList without copying when it already is one.
    def self.wrap(rows)
      return rows if rows.is_a?(self)

      new(rows || [])
    end

    # -- builder / append -------------------------------------------------

    # Append a row. `values` becomes index 2, `disabled` index 3 (disabled
    # requires values, since the slot is positional).
    def field(name, form_element, values: nil, disabled: nil)
      push(build_row(name, form_element, values, disabled))
      self
    end
    alias add field

    # Append a `:header` pseudo-row (no column, no form element behavior).
    def header(name)
      field(name, :header)
    end

    # Append one or more read-only `:info` rows.
    def info(*names)
      names.each { |n| field(n, :info) }
      self
    end

    # -- insertion --------------------------------------------------------

    def insert_after(anchor, name, form_element, values: nil, disabled: nil)
      insert_relative(anchor, 1, build_row(name, form_element, values, disabled))
    end

    def insert_before(anchor, name, form_element, values: nil, disabled: nil)
      insert_relative(anchor, 0, build_row(name, form_element, values, disabled))
    end

    # -- removal ----------------------------------------------------------

    # Remove every row for `name`. Idempotent: absent name is a no-op.
    def remove(name)
      sym = name.to_sym
      reject! { |row| row_name(row) == sym }
      self
    end

    # -- reordering -------------------------------------------------------

    def move_after(name, anchor)
      relocate(name, anchor, 1)
    end

    def move_before(name, anchor)
      relocate(name, anchor, 0)
    end

    # -- replacement ------------------------------------------------------

    # Swap the form element (and optional values/disabled) for an existing
    # attribute, preserving its position. No-op if the attribute is absent.
    def replace_element(name, form_element, values: nil, disabled: nil)
      idx = index_of(name)
      return self unless idx

      self[idx] = build_row(name, form_element, values, disabled)
      self
    end

    # -- queries ----------------------------------------------------------

    def index_of(name)
      sym = name.to_sym
      index { |row| row_name(row) == sym }
    end

    def include_attribute?(name)
      !index_of(name).nil?
    end

    def row_for(name)
      sym = name.to_sym
      find { |row| row_name(row) == sym }
    end

    # The form element symbol for `name`, or nil.
    def form_element_for(name)
      row = row_for(name)
      row && row[1]
    end

    # The values hash for `name` (row index 2), or nil.
    def values_for(name)
      row = row_for(name)
      row && row[2]
    end

    def names
      map { |row| row_name(row) }
    end

    private

    def row_name(row)
      first = row.respond_to?(:first) ? row.first : nil
      first&.to_sym
    end

    def build_row(name, form_element, values, disabled)
      raise ArgumentError, "disabled: requires values: (the row slot is positional)" if !disabled.nil? && values.nil?

      row = [ name.to_sym, form_element.to_sym ]
      row << values unless values.nil?
      row << disabled unless disabled.nil?
      row
    end

    def insert_relative(anchor, offset, row)
      idx = index_of(anchor)
      raise ArgumentError, "insert anchor :#{anchor} not found in attribute list" unless idx

      insert(idx + offset, row)
      self
    end

    def relocate(name, anchor, offset)
      row = row_for(name)
      raise ArgumentError, "move target :#{name} not found in attribute list" unless row
      raise ArgumentError, "cannot move :#{name} relative to itself" if name.to_sym == anchor.to_sym

      remove(name)
      idx = index_of(anchor)
      raise ArgumentError, "move anchor :#{anchor} not found in attribute list" unless idx

      insert(idx + offset, row)
      self
    end
  end

  # Convenience entry point mirroring AttributeList.build.
  def self.attribute_list(&block)
    AttributeList.build(&block)
  end
end
