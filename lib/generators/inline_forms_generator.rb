# -*- encoding : utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__),'../../app/helpers/inline_forms_helper.rb'))
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
  # Rails::Generators::GeneratedAttribute creates, among others, a attribute_type.
  # This attribute_type maps column types to form attribute helpers like text_field.
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
        SPECIAL_COLUMN_TYPES.merge(DEFAULT_COLUMN_TYPES).merge(RELATIONS).merge(SPECIAL_RELATIONS)[type] || :unknown
      end

      # Override the attribute_type to include our special column types.
      #
      # If a type is not in the Special Column Type hash, then the default
      # column type hash is used, and if that fails, the attribute_type
      # will be :unknown. Make sure to check your models for the :unknown.
      #
      def attribute_type
        SPECIAL_COLUMN_TYPES.merge(RELATIONS).has_key?(type) ? type : DEFAULT_FORM_ELEMENTS[type] || :unknown
      end

      def special_relation?
        SPECIAL_RELATIONS.has_key?(type)
      end

      def relation?
        RELATIONS.has_key?(type) || special_relation?
      end

      def migration?
        not ( column_type == :no_migration  ||
            name == "_presentation"       ||
            name == "_order"              ||
            name == "_enabled"            ||
            name == "_id" )
      end

      def attribute?
        not ( name == '_presentation'       ||
            name == '_order'              ||
            name == '_enabled'            ||
            name == "_id"                 ||
            relation? )
      end


    end
    argument :attributes, :type => :array,  :banner => "[name:form_element]..."

    source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

    # using flags.
    def set_some_flags
      @flag_not_accessible_through_html   = true
      @flag_create_migration              = true
      @flag_create_model                  = true
      @create_id                          = true
      for attribute in attributes
        @flag_not_accessible_through_html = false if attribute.name == '_enabled'
        @flag_create_migration            = false if attribute.name == '_no_migration'
        @flag_create_model                = false if attribute.name == '_no_model'
        @create_id                        = false if attribute.name == "_id" && attribute.type == :false
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
        @has_attached_files       = "\n"
        @presentation             = "\n"
        @order                    = "\n"
        @order_by_clause          = "  def self.order_by_clause\n" +
          "    \"name\"\n" +
          "  end\n" +
          "\n"
        @carrierwave_mounters     = "\n"
        @inline_forms_attribute_list  = String.new

        for attribute in attributes
          if attribute.column_type  == :belongs_to
            ## :drop_down, :references and :belongs_to all end up with the column_type :belongs_to
            @belongs_to << '  belongs_to :'         + attribute.name + "\n"
          end
          if attribute.type  == :image_field # upload images via carrierwave
            @carrierwave_mounters << '  mount_uploader :' + attribute.name + ', ' + "#{attribute.name}_uploader".camelcase + "\n"
          end
          if attribute.type         == :has_many ||
              attribute.type         == :has_many_destroy
            @has_many << '  has_many :'             + attribute.name
            @has_many << ', :dependent => :destroy' if attribute.type == :has_many_destroy
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
          if attribute.name == '_presentation'
            @presentation <<  "  def _presentation\n" +
              "    \"#{attribute.type.to_s}\"\n" +
              "  end\n" +
              "\n"
          end
          if attribute.name == '_order'
            @order <<         "  def <=>(other)\n" +
              "    self.#{attribute.type} <=> other.#{attribute.type}\n" +
              "  end\n" +
              "\n"
            @order_by_clause = "  def self.order_by_clause\n" +
              "    \"#{attribute.type}\"\n" +
              "  end\n" +
              "\n"
          end
          if attribute.attribute?
            attribute.attribute_type == :unknown ? commenter = '#' : commenter = ' '
            @inline_forms_attribute_list << commenter +
              '     [ :' +
              attribute.name +
              ' , "' + attribute.name +
              '", :' + attribute.attribute_type.to_s +
              " ], \n"
          end
        end
        unless @inline_forms_attribute_list.empty?
          @inline_forms_attribute_list =  "\n" +
            "  def inline_forms_attribute_list\n" +
            "    @inline_forms_attribute_list ||= [\n" +
            @inline_forms_attribute_list +
            "    ]\n" +
            "  end\n" +
            "\n"
        end
        template "model.erb", "app/models/#{model_file_name}.rb"
      end
    end

    def generate_resource_route
      if @flag_create_resource_route
        route <<-ROUTE.strip_heredoc
          resources :#{resource_name} do
            post 'revert', :on => :member
            get 'list_versions', :on => :member
            get 'close_versions_list', :on => :member
          end
        ROUTE
      end
    end

    def generate_migration
      if @flag_create_migration
        @columns = String.new

        for attribute in attributes
          if attribute.column_type == :image
            @columns << '      t.string    :' + attribute.name + "_file_name\n"
            @columns << '        t.string    :' + attribute.name + "_content_type\n"
            @columns << '        t.integer   :' + attribute.name + "_file_size\n"
            @columns << '        t.datetime  :' + attribute.name + "_updated_at\n"
          else
            if attribute.migration?
              attribute.attribute_type == :unknown ? commenter = '#' : commenter = ' '
              @columns << commenter +
                '     t.' +
                attribute.column_type.to_s +
                " :" +
                attribute.name +
                " \n"
            end
          end
        end
        @primary_key_option = @create_id ? '' : ', id: false'
        template "migration.erb", "db/migrate/#{time_stamp}_inline_forms_create_#{table_name}.rb"
      end
    end

    def add_second_top_bar
      copy_file "_inline_forms_tabs.html.erb", "app/views/_inline_forms_tabs.html.erb" unless File.exists?('app/views/_inline_forms_tabs.html.erb')
    end

    def add_tab
      unless @flag_not_accessible_through_html
        inject_into_file "app/controllers/application_controller.rb",
          "#{name.pluralize.underscore} ",
          :after => "ActionView::CompiledTemplates::MODEL_TABS = %w("
      end
    end

    def generate_test
      template "test.erb", "test/unit/#{test_file_name}.rb"
    end

    def generate_controller
      template "controller.erb", "app/controllers/#{controller_file_name}.rb" if @flag_create_controller
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
