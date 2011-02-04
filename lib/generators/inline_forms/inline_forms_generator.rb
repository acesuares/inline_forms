module InlineForms
  class InlineFormsGenerator < Rails::Generators::NamedBase

    Rails::Generators::GeneratedAttribute.class_eval do
      def migration_type
        # convert our form_elements to real types for migration
        case type
          # normal types don't get converted
          when :string, :text, :integer, :float, :decimal, :datetime, :timestamp, :time, :date, :binary, :boolean then type
          # our types get converted
          when :dropdown, :dropdown_with_values   then :integer
          when :check_box, :boolean_with_values   then :boolean
          when :date                      then :date
          when :text_area                 then :text
          else
            :unknown # migration will fail, probably.
        end
       
      end
      def field_type
        case type
          # out types don't get converted
          when :dropdown, :dropdown_with_values, :check_box, :boolean_with_values then type
          when :integer, :float, :decimal then :text_field # who knows if they wanted a dropdown?
          when :time                      then :time_select
          when :datetime, :timestamp      then :datetime_select
          when :date                      then :date_select
          when :text                      then :text_area
          when :boolean                   then :check_box
          else
            :unkown # form will fail to generatie, probably
        end
      end

   end

    argument :attributes, :type => :array,  :banner => "field:type field:type"

    source_root File.expand_path('../templates', __FILE__)

    def generate_model
      #copy_file "stylesheet.css", "public/stylesheets/#{file_name}.css"
      template "model.rb", "app/models/#{model_file_name}.rb"
    end

    def generate_controller
      template "controller.rb", "app/controllers/#{controller_file_name}.rb"
    end

    def generate_route
      route "resources :#{resource_name}"
    end

    def generate_migration
      template "migration.rb", "db/migrate/#{time_stamp}_inline_forms_create_#{table_name}.rb"
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
