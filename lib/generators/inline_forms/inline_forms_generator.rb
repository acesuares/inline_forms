module InlineForms
  class InlineFormsGenerator < Rails::Generators::NamedBase

    Rails::Generators::GeneratedAttribute.class_eval do
      # attributes are in the form name:type (f.i. price:integer)
      # we want to extend the types to our list of types
      # but some of the old types are still needed
      # f.i. price:integer turns into a text_field
      #
      def migration_type
        # convert any type into a migration type
        # each helper adds to this list
        # be aware that the standard list overwrites the customized list if we merge like this!
        SPECIAL_MIGRATION_TYPES.merge(DEFAULT_MIGRATION_TYPES).merge(RELATION_TYPES).merge(SPECIAL_RELATION_TYPES)[type] || :unknown
      end

      def field_type
        # convert standard types to one of ours
        SPECIAL_MIGRATION_TYPES.merge(RELATION_TYPES).merge(SPECIAL_RELATION_TYPES).has_key?(type) ? type : DEFAULT_FIELD_TYPES[type] || :unknown
      end

      def migration_name
        # convert some to _id
        ( relation? || field_type == :dropdown) ? name + '_id' : name
      end

      def belongs_to?
        relation? || field_type == :dropdown
      end
      
      def has_many?
        field_type == :associated
      end

      def relation?
        RELATION_TYPES.has_key?(field_type)
      end

      def special_relation?
        SPECIAL_RELATION_TYPES.has_key?(field_type)
      end

    end
    argument :attributes, :type => :array,  :banner => "[name:form_element]..."

    source_root File.expand_path('../templates', __FILE__)

    def copy_stylesheet
      copy_file File.expand_path('../../../../public/stylesheets', __FILE__) + "/inline_forms.css", "public/stylesheets/inline_forms.css" unless File.exists?('public/stylesheets/inline_forms.css')
    end

    def generate_model
      template "model.erb", "app/models/#{model_file_name}.rb"
    end

    def generate_controller
      template "controller.erb", "app/controllers/#{controller_file_name}.rb"
    end

    def generate_route
      route "resources :#{resource_name}"
    end

    def generate_migration
      template "migration.erb", "db/migrate/#{time_stamp}_inline_forms_create_#{table_name}.rb"
    end

    private
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

    def table_name
      name.pluralize.underscore
    end

    def time_stamp
      Time.now.utc.strftime("%Y%m%d%H%M%S")
      #    found it here http://whynotwiki.com/Ruby_/_Dates_and_times
    end

  end
end
