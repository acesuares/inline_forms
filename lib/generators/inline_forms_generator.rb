# -*- encoding : utf-8 -*-
require "inline_forms"
require_relative "inline_forms_attribute_overrides"
module InlineForms
  # == Usage
  # This generator generates a migration, a model and a controller.
  #
  #  rails g inline_forms Model attribute:type [attribute:type ...] [options]
  #
  # Read more about the possible types below.
  #
  # == Overriding Rails::Generators::GeneratedAttribute
  # When using a generator in the form
  #  rails g example_generator Modelname attribute:type attribute:type ...
  # an array with attributes and types is created for use in the generator.
  #
  # Rails::Generators::GeneratedAttribute creates, among others, an attribute_type.
  # This attribute_type maps column types to form attribute helpers like text_field.
  # We override it in `lib/generators/inline_forms_attribute_overrides.rb`
  # (shared with `InlineFormsAddtoGenerator`).
  #
  class InlineFormsGenerator < Rails::Generators::NamedBase
    argument :attributes, :type => :array,  :banner => "[name:form_element]..."
    class_option :allow_unknown, :type => :boolean, :default => false, :desc => "Allow unknown field types (legacy behavior: comment generated lines instead of failing)."

    source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

    # using flags.
    def set_some_flags
      @flag_not_accessible_through_html   = true
      @flag_create_migration              = true
      @flag_create_model                  = true
      @create_id                          = true
      @unknown_attributes                 = []
      for attribute in attributes
        @flag_not_accessible_through_html = false if attribute.name == '_enabled'
        @flag_create_migration            = false if attribute.name == '_no_migration'
        @flag_create_model                = false if attribute.name == '_no_model'
        @create_id                        = false if attribute.name == "_id" && attribute.type == :false
        if !attribute.name.start_with?('_') && (
            (attribute.attribute? && attribute.attribute_type == :unknown) ||
            (attribute.migration? && attribute.column_type == :unknown)
          )
          @unknown_attributes << "#{attribute.name}:#{attribute.type}"
        end
      end
      allow_unknown = options[:allow_unknown].to_s == 'true'
      if !allow_unknown && !@unknown_attributes.empty?
        raise Thor::Error,
          "Unknown field type(s): #{@unknown_attributes.uniq.join(', ')}. " +
          "Add a valid form element type or pass --allow-unknown to keep legacy commented output."
      end
      @flag_create_controller             = @flag_create_model
      @flag_create_resource_route         = @flag_create_model
    end

    def generate_model
      if @flag_create_model
        @belongs_to               = "\n"
        @has_many                 = "\n"
        @has_one                  = "\n"
        @habtm                    = "\n"
        @has_rich_text            = "\n"
        @has_attached_files       = "\n"
        @presentation             = "\n"
        @order                    = "\n"
        @list_scopes              = ""
        @carrierwave_mounters     = "\n"
        @stored_files             = String.new
        @inline_forms_attribute_list  = String.new
        rows                      = []

        for attribute in attributes
          if attribute.column_type  == :belongs_to
            ## :drop_down, :references and :belongs_to all end up with the column_type :belongs_to
            @belongs_to << '  belongs_to :'         + attribute.name + "\n"
          end
          # upload images or audio files via carrierwave
          case attribute.type when :image_field, :audio_field then
            @carrierwave_mounters << '  mount_uploader :' + attribute.name + ', ' + "#{attribute.name}_uploader".camelcase + "\n"
          end
          if attribute.type         == :has_many ||
              attribute.type         == :has_many_destroy
            @has_many << '  has_many :'             + attribute.name
            @has_many << ', dependent: :destroy' if attribute.type == :has_many_destroy
            @has_many << "\n"
          end
          if attribute.type         == :has_one
            @has_one << '  has_one :'               + attribute.name + "\n"
          end
          if attribute.type         == :habtm ||
              attribute.type         == :has_and_belongs_to_many ||
              attribute.type         == :check_list
            @habtm << '  has_and_belongs_to_many :' + attribute.name + "\n"
          end
          if attribute.type == :rich_text
            @has_rich_text << '  has_rich_text :' + attribute.name + "\n"
          end
          # Declared file slot: bytes + content type in the model's own table,
          # replace/remove/undo through the file trash (InlineForms::StoredFiles).
          if attribute.type == :simple_file_field
            @stored_files << "  include InlineForms::StoredFiles\n" if @stored_files.empty?
            @stored_files << '  inline_forms_file :' + attribute.name + "\n"
          end
          if attribute.name == '_presentation'
            @presentation <<  "  def _presentation\n" +
              "    \"#{attribute.type.to_s}\"\n" +
              "  end\n" +
              "\n"
          end
          # `_list_order:col` (preferred) and the legacy alias `_order:col`
          # both emit the inline_forms_list scope plus a Ruby `<=>` for
          # in-memory sort (used by check_list show on the association).
          if attribute.name == '_order' || attribute.name == '_list_order'
            if attribute.name == '_order'
              say_status :deprecated,
                         "_order:#{attribute.type} is deprecated; use _list_order:#{attribute.type}",
                         :yellow
            end
            @order <<         "  def <=>(other)\n" +
              "    self.#{attribute.type} <=> other.#{attribute.type}\n" +
              "  end\n" +
              "\n"
            @list_scopes << "  scope :inline_forms_list, -> { order(:#{attribute.type}, :id) }\n"
          end
          if attribute.name == '_list_search'
            @list_scopes << "  inline_forms_search_on :#{attribute.type}\n"
          end
          if attribute.attribute?
            commenter = attribute.attribute_type == :unknown ? '# ' : ''
            rows << "      #{commenter}[ :#{attribute.name}, :#{attribute.attribute_type} ]"
          end
        end
        unless rows.empty?
          # No comma after the last row (RuboCop omakase); inline_forms_addto adds
          # it when it appends one. Commented-out rows at the end go above that
          # last row, so that uncommenting one gives valid Ruby.
          last_row = rows.rindex { |row| !row.lstrip.start_with?('#') }
          last_row = rows.delete_at(last_row) if last_row
          rows.each { |row| @inline_forms_attribute_list << row << ",\n" }
          @inline_forms_attribute_list << last_row << "\n" if last_row
          @inline_forms_attribute_list =  "\n" +
            "  def inline_forms_attribute_list\n" +
            "    @inline_forms_attribute_list ||= [\n" +
            @inline_forms_attribute_list +
            "    ]\n" +
            "  end\n" +
            "\n"
        end
        template("model.erb", "app/models/#{model_file_name}.rb") { |content| tidy_class_body(content) }
      end
    end

    def generate_resource_route
      if @flag_create_resource_route
        file_routes = file_slot_attributes.any? ? "\n            InlineForms.file_routes(self)" : ""
        route <<-ROUTE.strip_heredoc
          resources :#{resource_name} do
            post "revert", on: :member
            get "list_versions", on: :member#{file_routes}
          end
        ROUTE
      end
    end

    def generate_migration
      if @flag_create_migration
        @columns = String.new

        for attribute in attributes
          if attribute.type == :simple_file_field
            columns = InlineForms.file_slot_columns(attribute.name)
            @columns << '      t.string :' + columns[:filename] + "\n"
            @columns << '      t.binary :' + columns[:data] + ", **(connection.adapter_name.match?(/mysql|trilogy/i) ? { size: :long } : {})\n"
            @columns << '      t.string :' + columns[:content_type] + "\n"
          elsif attribute.column_type == :image
            @columns << '      t.string    :' + attribute.name + "_file_name\n"
            @columns << '        t.string    :' + attribute.name + "_content_type\n"
            @columns << '        t.integer   :' + attribute.name + "_file_size\n"
            @columns << '        t.datetime  :' + attribute.name + "_updated_at\n"
          else
            if attribute.migration?
              commenter = attribute.attribute_type == :unknown ? '# ' : ''
              @columns << "      #{commenter}t.#{attribute.column_type} :#{attribute.name}" \
                          "#{attribute.inline_forms_column_options}\n"
            end
          end
        end
        @primary_key_option = @create_id ? '' : ', id: false'
        template "migration.erb", "db/migrate/#{time_stamp}_inline_forms_create_#{table_name}.rb"
      end
    end

    def add_tab
      return if @flag_not_accessible_through_html

      # The installer seeds `MODEL_TABS = %w[<user_model_route> ]` (`%w( )`
      # before 8.1.72) in
      # `config/initializers/inline_forms.rb` before any `rails g inline_forms`
      # runs. Inject each generated model's pluralised route token into that
      # list so the inline_forms top-bar dropdown (rendered by
      # `app/views/inline_forms/_header.html.erb`) surfaces every
      # HTML-reachable model. No-op when the initializer is absent (e.g. a
      # consumer running `rails g inline_forms` in a non-installer-shaped app)
      # or when the token is already present (idempotent re-run).
      relative_path = "config/initializers/inline_forms.rb"
      marker = /MODEL_TABS = %w[\[(]/
      tab_token = "#{name.pluralize.underscore} "
      full_path = File.join(destination_root, relative_path)
      return unless File.exist?(full_path)

      content = File.read(full_path)
      return unless content.match?(marker)
      # One of the words, not a substring: "showcases" is not there because
      # "form_element_showcases" is. force: Thor skips on a substring too.
      return if content[/MODEL_TABS = %w[\[(]([^\])]*)/, 1].to_s.split.include?(tab_token.rstrip)

      inject_into_file relative_path, tab_token, after: marker, force: true
    end

    def generate_test
      template "test.erb", "test/unit/#{test_file_name}.rb"
    end

    def generate_controller
      template "controller.erb", "app/controllers/#{controller_file_name}.rb" if @flag_create_controller
    end


    private
    # The optional parts of model.erb each bring their own blank lines: none
    # right after `class` or before its `end`, and never two in a row.
    def tidy_class_body(content)
      content.gsub(/\n{3,}/, "\n\n")
             .sub(/\A(class [^\n]*\n)\n+/, '\1')
             .sub(/\n+end\s*\z/, "\nend\n")
    end

    def file_slot_attributes
      attributes.select { |attribute| attribute.type == :simple_file_field }
    end

    def model_file_name
      name.underscore
    end

    def resource_name
      name.pluralize.underscore
    end

    def controller_name
      name.pluralize + 'Controller'
    end

    def controller_file_name
      controller_name.underscore
    end

    def test_name
      name + 'Test'
    end

    def test_file_name
      test_name.underscore
    end

    def table_name
      name.pluralize.underscore
    end

    def time_stamp
      Time.now.utc.strftime("%Y%m%d%H%M%S")
      #    found it here http://whynotwiki.com/Ruby_/_Dates_and_times
    end

  end
end
