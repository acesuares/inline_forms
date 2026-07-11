# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "inline_forms_schema_gui/version"

Gem::Specification.new do |s|
  s.name        = "inline_forms_schema_gui"
  s.version     = InlineFormsSchemaGui::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = [ "Ace Suares" ]
  s.email       = [ "ace@suares.com" ]
  s.homepage    = %q(http://github.com/acesuares/inline_forms)
  s.summary     = %q(Schema-change GUI for inline_forms apps.)
  s.description = %q(Mountable engine that adds a browser GUI for schema changes (add a field to a model) to inline_forms apps. Drives the staging services in inline_forms; generate-only, never runs db:migrate itself.)
  s.licenses    = [ "MIT" ]
  s.required_ruby_version = ">= 4.0.0"

  s.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,lib}/**/*", "CHANGELOG.md"].select { |f| File.file?(f) }
  end
  s.require_paths = [ "lib" ]

  s.add_dependency("inline_forms", "~> 8")
end
