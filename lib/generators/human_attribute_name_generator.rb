class HumanAttributeNameGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)
 
  def copy_initializer_file
      copy_file "model_instance_human_attribute_name.rb", "config/initializers/human_attribute_name.rb"
  end
end
