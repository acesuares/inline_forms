module InlineForms
  # == Usage
  # This generator generates a migration, a model and a controller.
  #
  #  rails g inline_forms Model attribute:type [attribute:type ...] [options]
  #
  # Read more about the possible types below.
  #
  # = Overriding Rails::Generators::GeneratedAttribute
  # When using a generator in the form
  #  rails g example_generator Modelname attribute:type attribute:type ...
  # an array with attributes and types is created for use in the generator.
  #
  # Rails::Generators::GeneratedAttribute creates, among others, a field_type.
  # This field_type maps column types to form field helpers like text_field.
  # We override it here to make our own.
  #
  class InlineFormsGenerator < Rails::Generators::NamedBase
    Rails::Generators::GeneratedAttribute.class_eval do #:doc:
      # Deducts the column_type for migrations from the type.
      #
      # We first merge the Special Column Types with the Default Column Types,
      # which has the effect that the Default Column Types with the same key override
      # the Special Column Types.
      #
      # If the type is not in the merged hash, then column_type defaults to :unknown
      #
      # You are advised to check you migrations for the :unknown, because either you made a
      # typo in the generator command line or you need to add a Form Element!
      #
      def column_type
        SPECIAL_COLUMN_TYPES.merge(DEFAULT_COLUMN_TYPES).merge(RELATIONS)[type] || :unknown
      end

      # Override the field_type to include our special column types.
      #
      # If a type is not in the Special Column Type hash, then the default
      # column type hash is used, and if that fails, the field_type
      # will be :unknown. Make sure to check your models for the :unknown.
      #
      def field_type
        SPECIAL_COLUMN_TYPES.merge(RELATIONS).has_key?(type) ? type : DEFAULT_COLUMN_TYPES[type] || :unknown
      end
      
      def relation?
        RELATIONS.has_key?(type) || special_relation?
      end

      def special_relation?
        SPECIAL_RELATIONS.has_key?(type)
      end

      def has_many?
        field_type == :associated
      end


    end
    argument :attributes, :type => :array,  :banner => "[name:form_element]..."

    source_root File.expand_path('../templates', __FILE__)

    def copy_stylesheet
      copy_file File.expand_path('../../../../public/stylesheets', __FILE__) + "/inline_forms.css", "public/stylesheets/inline_forms.css" unless File.exists?('public/stylesheets/inline_forms.css')
    end

    def generate_model
      @belongs_to         = "\n"
      @has_many           = "\n"
      @has_attached_files = "\n"
      @presentation       = "\n"
      @inline_forms_field_list = String.new

      for attribute in attributes
        if attribute.column_type == :belongs_to || attribute.type == :belongs_to
          @belongs_to << '  belongs_to :' + attribute.name + "\n"
        end
        if attribute.type == :has_many
          @has_many << '  has_many :' + attribute.name + "\n"
        end
        if attribute.type == :image
          @has_attached_files << "  has_attached_file :#{attribute.name},
               :styles => { :medium => \"300x300>\", :thumb => \"100x100>\" }\n"
        end
        if attribute.name == '_presentation'
          @presentation <<  "  def _presentation\n" +
                            "    \"#{attribute.type.to_s}\"\n" +
                            "  end\n" +
                            "\n"
        end
        unless attribute.name == '_presentation' || attribute.relation?
          attribute.field_type == :unknown ? commenter = '#' : commenter = ' '
          @inline_forms_field_list << commenter +
                                      '     [ :' +
                                      attribute.name +
                                      ', "' + attribute.name +
                                      '", :' + attribute.field_type.to_s +
                                      " ], \n"
        end
      end
      unless @inline_forms_field_list.empty?
        @inline_forms_field_list =  "\n" +
                                    "  def inline_forms_field_list\n" +
                                    "    [\n" +
                                    @inline_forms_field_list +
                                    "    ]\n" +
                                    "  end\n" +
                                    "\n"
      end
      template "model.erb", "app/models/#{model_file_name}.rb"
    end

    def generate_controller
      template "controller.erb", "app/controllers/#{controller_file_name}.rb"
    end

    def generate_route
      route "resources :#{resource_name}"
    end

    def generate_migration
      @columns = String.new

      for attribute in attributes
        if attribute.column_type == :image
          @columns << '      t.string    :' + attribute.name + "_file_name\n"
          @columns << '        t.string    :' + attribute.name + "_content_type\n"
          @columns << '        t.integer   :' + attribute.name + "_file_size\n"
          @columns << '        t.datetime  :' + attribute.name + "_updated_at\n"
        else
          unless attribute.name == '_presentation' || attribute.special_relation?
            attribute.field_type == :unknown ? commenter = '#' : commenter = ' '
            @columns << commenter +
                        '     t.' +
                        attribute.column_type.to_s +
                        " :" +
                        attribute.name +
                        " \n"
          end
        end
      end
      template "migration.erb", "db/migrate/#{time_stamp}_inline_forms_create_#{table_name}.rb"
    end

    def add_tab
      copy_file "_inline_forms_tabs.html.erb", "app/views/_inline_forms_tabs.html.erb" unless File.exists?('app/views/_inline_forms_tabs.html.erb')
      inject_into_file "app/views/_inline_forms_tabs.html.erb",
              "  <%= tab.#{name.underscore} '#{name}', #{name.pluralize.underscore + '_path'} %>\n",
              :after => "<% tabs_tag :open_tabs => { :id => \"tabs\" } do |tab| %>\n"
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
