# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "inline_forms/version"
require "inline_forms/gem_files"

Gem::Specification.new do |s|
  s.name        = "inline_forms"
  s.version     = InlineForms::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ace Suares", "Lemuel Boyce", "Manuel Ortega"]
  s.email       = ["ace@suares.com"]
  s.homepage    = %q{http://github.com/acesuares/inline_forms}
  s.summary     = %q{Inline editing of forms for Rails 8.}
  s.description = %q{Inline Forms eases setup of admin-style forms with inline editing. Field lists are declared on the model. Requires Rails 8.0.x, Ruby >= 4.0, and validation_hints ~> 8.}
  s.licenses    = ["MIT"]
  s.required_ruby_version = ">= 4.0.0"

  s.files      = InlineFormsGemFiles.gem_files(include_installer: false)
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency("validation_hints", ">= 8.0.4", "< 9.0")
  s.add_dependency("rails", ">= 8.0", "< 8.1")
  s.add_dependency("rails-i18n", ">= 8.0", "< 9.0")

  s.add_development_dependency("minitest", "~> 5.0")
end
