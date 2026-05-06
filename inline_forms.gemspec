# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "inline_forms/version"

Gem::Specification.new do |s|
  s.name        = "inline_forms"
  s.version     = InlineForms::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ace Suares", "Lemuel Boyce", "Manuel Ortega"]
  s.email       = ["ace@suares.com"]
  s.homepage    = %q{http://github.com/acesuares/inline_forms}
  s.summary     = %q{Inline editing of forms.}
  s.description = %q{Inline Forms aims to ease the setup of forms that provide inline editing. The field list can be specified in the model.}
  s.licenses    = ["MIT"]
  s.required_ruby_version = ">= 3.2.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = ["inline_forms"]
  s.require_paths = ["lib"]

  s.add_dependency('rvm', '>= 1.11', '< 2.0')
  s.add_dependency('thor', '>= 1.0', '< 2.0')
  s.add_dependency('validation_hints', '>= 0.2', '< 1.0')
  s.add_dependency('rails', '>= 7.0.0', '< 7.1')
  s.add_dependency('rails-i18n', '>= 7.0', '< 8.0')

  s.add_development_dependency("minitest", "~> 5.0")

end
