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
  s.summary     = %q{Inline editing of forms. Versions after 6.2.14 are currently broken.}
  s.description = %q{Inline Forms aims to ease the setup of forms that provide inline editing. The field list can be specified in the model. Versions after 6.2.14 are currently broken, and we will post a notice when the gem is good again.}
  s.licenses    = ["MIT"]
  s.required_ruby_version = ">= 4.0.0"

  s.files      = InlineFormsGemFiles.gem_files(include_installer: false)
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency("validation_hints", "~> 7")
  s.add_dependency("rails", ">= 7.2.3.1", "< 7.3")
  s.add_dependency("rails-i18n", ">= 7.0", "< 8.0")

  s.add_development_dependency("minitest", "~> 5.0")
end
