# -*- encoding : utf-8 -*-
require "inline_forms"
require_relative "inline_forms_attribute_overrides"

# == Usage
#
#   rails g inline_forms_addto Model attribute:type [attribute:type ...] [options]
#
# Adds fields to an existing inline_forms model. Emits an additive
# migration (`add_column` / `add_reference` / single :string column for
# `:image_field`/`:audio_field`) and edits the model file:
#
# * adds `belongs_to` / `has_many` / `has_one` / `has_and_belongs_to_many` /
#   `has_rich_text` / `mount_uploader` lines (idempotent)
# * inserts new rows into the model's `inline_forms_attribute_list`
#
# Does NOT touch routes, the controller, or `MODEL_TABS` (those are
# already wired for the existing model). Use `rails g inline_forms <Model>`
# to create new models.
#
# == Special generator names
#
# `_no_model`, `_no_migration`, `_id`, `_enabled` are install-time only and
# are rejected. `_presentation`, `_list_order`, `_list_search` are
# accepted but only acted on when `--replace` is passed; otherwise the
# generator skips them with a `say_status :skipped` notice.
#
# Top-level (no `InlineForms` module wrapper) so Rails resolves
# `rails g inline_forms_addto Model …` to this class without the
# `inline_forms:inline_forms_addto` double-segment trick that Rails only
# applies for matching `name:name` pairs (`inline_forms:inline_forms`).
class InlineFormsAddtoGenerator < Rails::Generators::NamedBase
    INSTALL_TIME_ONLY_NAMES = %w[_no_model _no_migration _id _enabled].freeze
    REPLACE_ONLY_NAMES      = %w[_presentation _list_order _list_search _order].freeze

    # Form elements that render a set of choices and therefore need a values
    # hash as the 3rd element of their attribute_list row. Emitting the bare
    # 2-element row for these raises at show time, so we insert a placeholder
    # hash and warn the user to fill it in.
    VALUE_BEARING_ELEMENTS = %i[
      dropdown_with_values
      dropdown_with_integers
      dropdown_with_values_with_stars
      radio_button
      check_box
      scale_with_integers
      scale_with_values
    ].freeze

    # attribute_list rows whose form element (or name) marks the start of the
    # trailing "metadata" block. The smart-default placement inserts new rows
    # above this block instead of at the very end of the list.
    METADATA_ROW_NAMES = %w[created_at updated_at].freeze

    argument :attributes, type: :array, banner: "[name:form_element]..."
    class_option :allow_unknown, type: :boolean, default: false,
                 desc: "Allow unknown field types (legacy behavior: comment generated lines instead of failing)."
    class_option :replace, type: :boolean, default: false,
                 desc: "Replace existing _presentation/_list_order/_list_search instead of skipping."
    class_option :before, type: :string, default: nil,
                 desc: "Insert the new attribute_list row before this existing attribute name."
    class_option :after, type: :string, default: nil,
                 desc: "Insert the new attribute_list row after this existing attribute name."

    source_root File.expand_path("inline_forms_addto/templates", __dir__)

    def validate!
      unless File.exist?(File.join(destination_root, model_file_path))
        raise Thor::Error,
          "Model #{model_file_path} not found. " \
          "Use `rails g inline_forms #{name} ...` for new models."
      end
    end

    def set_some_flags
      @unknown_attributes = []
      @forbidden_names    = []
      @skipped_replace_names = []
      attributes.each do |attribute|
        if INSTALL_TIME_ONLY_NAMES.include?(attribute.name)
          @forbidden_names << attribute.name
          next
        end
        if REPLACE_ONLY_NAMES.include?(attribute.name) && !options[:replace]
          @skipped_replace_names << "#{attribute.name}:#{attribute.type}"
          next
        end
        if !attribute.name.start_with?("_") && (
            (attribute.attribute? && attribute.attribute_type == :unknown) ||
            (attribute.migration? && attribute.column_type == :unknown)
          )
          @unknown_attributes << "#{attribute.name}:#{attribute.type}"
        end
      end

      unless @forbidden_names.empty?
        raise Thor::Error,
          "Names #{@forbidden_names.uniq.join(', ')} are install-time only " \
          "and not supported by inline_forms_addto."
      end

      allow_unknown = options[:allow_unknown].to_s == "true"
      if !allow_unknown && !@unknown_attributes.empty?
        raise Thor::Error,
          "Unknown field type(s): #{@unknown_attributes.uniq.join(', ')}. " \
          "Add a valid form element type or pass --allow-unknown to keep legacy commented output."
      end

      @skipped_replace_names.each do |label|
        say_status :skipped, "#{label} (pass --replace to rewrite the existing scope/method)", :yellow
      end
    end

    def generate_migration
      @migration_lines = String.new
      attributes.each do |attribute|
        next if INSTALL_TIME_ONLY_NAMES.include?(attribute.name)
        next if REPLACE_ONLY_NAMES.include?(attribute.name)
        next unless attribute.migration?

        if attribute.column_type == :belongs_to
          @migration_lines << "    add_reference :#{table_name}, :#{attribute.name}, foreign_key: true\n"
        else
          commenter = attribute.attribute_type == :unknown ? "#" : " "
          @migration_lines << "#{commenter}    add_column :#{table_name}, :#{attribute.name}, :#{attribute.column_type}\n"
        end
      end

      return if @migration_lines.empty?

      template "add_columns_migration.erb",
               "db/migrate/#{unique_time_stamp}_#{migration_file_basename}.rb"
    end

    def update_model
      attributes.each do |attribute|
        next if INSTALL_TIME_ONLY_NAMES.include?(attribute.name)
        next if REPLACE_ONLY_NAMES.include?(attribute.name) && !options[:replace]

        if REPLACE_ONLY_NAMES.include?(attribute.name) && options[:replace]
          replace_special!(attribute)
          next
        end

        case attribute.column_type
        when :belongs_to
          inject_class_line!("  belongs_to :#{attribute.name}\n")
        end

        case attribute.type
        when :image_field, :audio_field
          uploader_class = "#{attribute.name}_uploader".camelcase
          inject_class_line!("  mount_uploader :#{attribute.name}, #{uploader_class}\n")
        when :has_many
          inject_class_line!("  has_many :#{attribute.name}\n")
        when :has_many_destroy
          inject_class_line!("  has_many :#{attribute.name}, :dependent => :destroy\n")
        when :has_one
          inject_class_line!("  has_one :#{attribute.name}\n")
        when :habtm, :has_and_belongs_to_many, :check_list
          inject_class_line!("  has_and_belongs_to_many :#{attribute.name}\n")
        when :rich_text
          inject_class_line!("  has_rich_text :#{attribute.name}\n")
        end

        next unless attribute.attribute?

        add_attribute_list_row!(attribute)
      end
    end

    # Run last (Thor invokes public methods in definition order). The model
    # row was injected above, but it references a column that does not exist
    # until the generated migration is applied; rendering the model before
    # then raises. Remind the user loudly. No-op when no migration was written
    # (e.g. only has_many/rich_text/habtm additions).
    def remind_to_migrate
      return if @migration_lines.nil? || @migration_lines.empty?

      say ""
      say "  Next step: apply the generated migration before rendering #{model_class_name}:", :yellow
      say "    bundle exec rails db:migrate", :yellow
      say "  (the attribute_list row was added now, but its column only exists after migrating.)", :yellow
    end

    private

    def model_file_name
      name.underscore
    end

    def model_file_path
      "app/models/#{model_file_name}.rb"
    end

    def model_class_name
      name.camelize
    end

    def table_name
      name.pluralize.underscore
    end

    def migration_class_name
      "InlineFormsAddTo#{table_name.camelize}#{migration_class_suffix}"
    end

    # Suffix keeps re-runs from colliding (Rails would reject duplicate
    # migration class names). Built from the column names being added.
    def migration_class_suffix
      cols = attributes.reject { |a| INSTALL_TIME_ONLY_NAMES.include?(a.name) || REPLACE_ONLY_NAMES.include?(a.name) }
                       .map { |a| a.name.camelize }
      cols.empty? ? "Fields" : cols.first(3).join
    end

    def migration_file_basename
      cols = attributes.reject { |a| INSTALL_TIME_ONLY_NAMES.include?(a.name) || REPLACE_ONLY_NAMES.include?(a.name) }
                       .map(&:name)
      label = cols.first(3).join("_")
      label = "fields" if label.empty?
      "inline_forms_add_to_#{table_name}_#{label}"
    end

    def time_stamp
      # Mirrors InlineFormsGenerator#time_stamp.
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end

    # Idempotent inject: skip if `line` (sans trailing newline) already
    # appears inside the model file. Uses `inject_into_class` so the
    # injection lands at the top of the class body (after `class Foo <
    # ApplicationRecord`).
    def inject_class_line!(line)
      content = File.read(File.join(destination_root, model_file_path))
      probe = line.rstrip
      if content.include?(probe)
        say_status :identical, "#{model_file_path}: #{probe.strip}", :blue
        return
      end
      inject_into_class model_file_path, model_class_name, line
    end

    # Inserts a new row into the existing `inline_forms_attribute_list`
    # method. Falls back to appending a fresh method when the model has no
    # generator-shaped list (e.g. only the inherited
    # `attr_writer :inline_forms_attribute_list` and no body).
    #
    # Row-aware, not regex-greedy: we locate the `[` after
    # `@inline_forms_attribute_list ||=` and bracket-depth scan to its
    # matching `]`, so the edit survives `].freeze`, trailing comments, and
    # any methods defined after the list. Placement honors `--after`/`--before`
    # (by attribute name) and otherwise lands above the trailing metadata block
    # (`:info` rows / created_at / updated_at, and a `:header` directly above
    # them) instead of after it.
    def add_attribute_list_row!(attribute)
      path    = File.join(destination_root, model_file_path)
      content = File.read(path)

      # Idempotent: skip if a row for this attribute already exists anywhere.
      if content.match?(/\[\s*:#{Regexp.escape(attribute.name)}\s*,/)
        say_status :identical, "#{model_file_path}: row :#{attribute.name}", :blue
        return
      end

      bounds = attribute_list_bounds(content)
      unless bounds
        say_status :warn, "#{model_file_path}: no inline_forms_attribute_list found, appending a fresh method", :yellow
        body = <<~RUBY.gsub(/^/, "  ")

          def inline_forms_attribute_list
            @inline_forms_attribute_list ||= [
              #{attribute_row_literal(attribute)},
            ]
          end
        RUBY
        inject_into_class model_file_path, model_class_name, body
        return
      end

      warn_if_value_bearing!(attribute)

      open_idx, close_idx = bounds
      inner  = content[(open_idx + 1)...close_idx]
      lines  = inner.lines
      indent = detect_row_indent(lines)
      new_line = "#{indent}#{attribute_row_literal(attribute)},\n"

      insert_at, note = insertion_index(lines, attribute)

      # Keep the array valid: ensure the row we insert after ends with a comma.
      if insert_at.positive?
        prev = lines[insert_at - 1]
        if prev && prev.match?(/\S/) && !prev.match?(/,\s*\z/)
          lines[insert_at - 1] = prev.sub(/(\S)(\s*)\z/, "\\1,\\2")
        end
      end

      lines.insert(insert_at, new_line)
      new_content = content[0..open_idx] + lines.join + content[close_idx..-1]
      File.write(path, new_content)
      say_status :insert, "#{model_file_path}: row :#{attribute.name}#{note}", :green
    end

    # Returns [open_bracket_index, close_bracket_index] for the
    # `@inline_forms_attribute_list ||= [ ... ]` array literal, or nil when the
    # model has no such list. Bracket-depth scan; nested `[ ]` (e.g. an
    # options_disabled array inside a choice row) balances correctly.
    def attribute_list_bounds(content)
      m = content.match(/@inline_forms_attribute_list\s*\|\|=\s*\[/)
      return nil unless m

      open_idx = m.end(0) - 1 # index of the '[' itself
      depth = 0
      i = open_idx
      while i < content.length
        case content[i]
        when "[" then depth += 1
        when "]"
          depth -= 1
          return [ open_idx, i ] if depth.zero?
        end
        i += 1
      end
      nil
    end

    # Decide where the new row goes. Returns [line_index, status_note].
    def insertion_index(lines, _attribute)
      if (anchor = options[:after].to_s) != ""
        idx = row_line_index(lines, anchor)
        return [ idx + 1, " (after :#{anchor})" ] if idx
        say_status :warn, "#{model_file_path}: --after #{anchor} not found; using default placement", :yellow
      elsif (anchor = options[:before].to_s) != ""
        idx = row_line_index(lines, anchor)
        return [ idx, " (before :#{anchor})" ] if idx
        say_status :warn, "#{model_file_path}: --before #{anchor} not found; using default placement", :yellow
      end

      if (meta = metadata_start_index(lines))
        return [ meta, " (above metadata)" ]
      end

      [ last_row_index(lines) + 1, "" ]
    end

    def row_line_index(lines, name)
      lines.index { |l| row_name(l) == name.to_s }
    end

    def row_name(line)
      m = line.match(/\A\s*\[\s*:(\w+)\s*,/)
      m && m[1]
    end

    def row_element(line)
      m = line.match(/\A\s*\[\s*:\w+\s*,\s*:(\w+)/)
      m && m[1]
    end

    # Index of the first row that starts the trailing metadata block. If a
    # `:header` sits directly above that row, the header is treated as the
    # block start (so the new field lands above the header, not between it and
    # its info rows). nil when the list has no metadata block.
    def metadata_start_index(lines)
      first = nil
      lines.each_with_index do |l, i|
        if row_element(l) == "info" || METADATA_ROW_NAMES.include?(row_name(l))
          first = i
          break
        end
      end
      return nil unless first

      prev = first - 1
      (prev >= 0 && row_element(lines[prev]) == "header") ? prev : first
    end

    def last_row_index(lines)
      idx = nil
      lines.each_with_index { |l, i| idx = i if row_name(l) }
      idx || (lines.length - 1)
    end

    def detect_row_indent(lines)
      lines.each do |l|
        m = l.match(/\A(\s*)\[/)
        return m[1] if m
      end
      "      " # 6 spaces, matching the create-time template
    end

    # `[ :name, :element ]`, or `[ :name, :element, { 1 => 'one', 2 => 'two' } ]`
    # for value-bearing choice elements (a placeholder the user then edits).
    def attribute_row_literal(attribute)
      el = attribute.attribute_type
      if VALUE_BEARING_ELEMENTS.include?(el)
        "[ :#{attribute.name}, :#{el}, { 1 => 'one', 2 => 'two' } ]"
      else
        "[ :#{attribute.name}, :#{el} ]"
      end
    end

    def warn_if_value_bearing!(attribute)
      return unless VALUE_BEARING_ELEMENTS.include?(attribute.attribute_type)

      say_status :warn,
                 "#{model_file_path}: :#{attribute.name} is a #{attribute.attribute_type}; " \
                 "edit the placeholder values hash { 1 => 'one', ... }",
                 :yellow
    end

    def unique_time_stamp
      base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
      dir  = File.join(destination_root, "db", "migrate")
      existing = Dir.glob(File.join(dir, "*.rb")).filter_map do |f|
        File.basename(f)[/\A(\d{14})/, 1]&.to_i
      end
      [ base, (existing.max || 0) + 1 ].max.to_s.rjust(14, "0")
    end

    def replace_special!(attribute)
      case attribute.name
      when "_presentation"
        new_method = "  def _presentation\n    \"#{attribute.type}\"\n  end\n"
        if File.read(File.join(destination_root, model_file_path)).match?(/def _presentation\b/)
          gsub_file model_file_path,
                    /  def _presentation\b.*?\n  end\n/m,
                    new_method
        else
          inject_into_class model_file_path, model_class_name, "\n#{new_method}"
        end
      when "_list_order", "_order"
        col = attribute.type
        new_scope = "  scope :inline_forms_list, -> { order(:#{col}, :id) }\n"
        new_spaceship = "  def <=>(other)\n    self.#{col} <=> other.#{col}\n  end\n"
        path = File.join(destination_root, model_file_path)
        content = File.read(path)
        if content.match?(/scope :inline_forms_list\b/)
          gsub_file model_file_path, /  scope :inline_forms_list, ->.*\n/, new_scope
        else
          inject_into_class model_file_path, model_class_name, new_scope
        end
        if content.match?(/def <=>\(other\)/)
          gsub_file model_file_path, /  def <=>\(other\).*?\n  end\n/m, new_spaceship
        else
          inject_into_class model_file_path, model_class_name, "\n#{new_spaceship}"
        end
      when "_list_search"
        col = attribute.type
        new_scope = "  scope :inline_forms_search, ->(q) { where(\"#{col} LIKE ?\", \"%\#{q}%\") }\n"
        if File.read(File.join(destination_root, model_file_path)).match?(/scope :inline_forms_search\b/)
          gsub_file model_file_path, /  scope :inline_forms_search, ->.*\n/, new_scope
        else
          inject_into_class model_file_path, model_class_name, new_scope
        end
      end
    end
end

module InlineForms
  # Backwards-compatible alias (tests and any programmatic invokers that
  # addressed the namespaced version while the generator was scoped to
  # `module InlineForms`). Rails generator discovery uses the top-level
  # constant above.
  InlineFormsAddtoGenerator = ::InlineFormsAddtoGenerator unless const_defined?(:InlineFormsAddtoGenerator, false)
end
