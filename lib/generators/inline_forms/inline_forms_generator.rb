class InlineFormsGenerator < Rails::Generators::NamedBase
  argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"

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
