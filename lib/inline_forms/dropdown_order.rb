# frozen_string_literal: true

module InlineForms
  # The order in which a table-backed form element (dropdown,
  # dropdown_with_other, check_list) offers its records. First match wins:
  #
  # 1. the model declares `inline_forms_dropdown_order :column, :asc|:desc`;
  # 2. the table has a `dropdown_order` column (ascending), so a lookup can
  #    put '---' / 'onbekend' first and process phases in process order;
  # 3. the ORDER BY of the model's `inline_forms_list` scope (its list order;
  #    only the order: a where in that scope does not hide records here, and
  #    its joins come along as LEFT joins, for an order on a joined table);
  # 4. database order (a default_scope order included).
  #
  # 1 and 2 replace any default_scope order, put NULLs last (a record nobody
  # numbered yet goes to the end) and break ties on the primary key. 3 keeps a
  # default_scope order after it, unless the scope reorders: the scope's own
  # order_values already say which.
  #
  # The macro is on every Active Record model (engine initializer), so hosts
  # need no ApplicationRecord change.
  module DropdownOrder
    COLUMN = "dropdown_order"
    DIRECTIONS = %i[asc desc].freeze

    module ClassMethods
      def inline_forms_dropdown_order(column, direction = :asc)
        direction = direction.to_s.downcase.to_sym
        unless DIRECTIONS.include?(direction)
          raise ArgumentError, "inline_forms_dropdown_order: direction must be :asc or :desc, got #{direction.inspect}"
        end

        @inline_forms_dropdown_order = [ column.to_s, direction ].freeze
      end

      # [column, direction] declared on this class or an ancestor, or nil.
      def inline_forms_dropdown_order_spec
        return @inline_forms_dropdown_order if defined?(@inline_forms_dropdown_order)

        superclass.inline_forms_dropdown_order_spec if superclass.respond_to?(:inline_forms_dropdown_order_spec)
      end
    end

    def self.apply(relation)
      klass = relation.klass
      column, direction = klass.inline_forms_dropdown_order_spec if klass.respond_to?(:inline_forms_dropdown_order_spec)
      column, direction = COLUMN, :asc if column.nil? && klass.column_names.include?(COLUMN)

      if column
        unless klass.column_names.include?(column)
          raise ArgumentError, "#{klass.name}.inline_forms_dropdown_order: #{klass.table_name} has no column #{column.inspect}"
        end

        table = klass.arel_table
        keys = [ table[column].public_send(direction).nulls_last ]
        keys << table[klass.primary_key].asc if klass.primary_key && klass.primary_key != column
        relation.reorder(*keys)
      elsif (list = list_scope(klass))&.order_values&.any?
        with_list_joins(relation, list).reorder(*list.order_values)
      else
        relation
      end
    end

    def self.list_scope(klass)
      klass.inline_forms_list if klass.respond_to?(:inline_forms_list)
    end

    # An association join becomes a LEFT join, so a record without the
    # association stays in the list. A string join can't: it stays as written.
    def self.with_list_joins(relation, list)
      named, raw = list.joins_values.partition { |join| join.is_a?(Symbol) || join.is_a?(Hash) }
      named = (named | list.left_outer_joins_values | list.eager_load_values) - relation.joins_values
      raw -= relation.joins_values
      relation = relation.left_outer_joins(*named) if named.any?
      relation = relation.joins(*raw) if raw.any?
      relation
    end
  end
end
