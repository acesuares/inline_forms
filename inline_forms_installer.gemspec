# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "inline_forms/gem_files"
require "inline_forms_installer/version"

Gem::Specification.new do |s|
  s.name        = "inline_forms_installer"
  s.version     = InlineFormsInstaller::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ace Suares", "Lemuel Boyce", "Manuel Ortega"]
  s.email       = ["ace@suares.com"]
  s.homepage    = %q{http://github.com/acesuares/inline_forms}
  s.summary     = %q{CLI and Rails app template for generating inline_forms applications.}
  s.description = %q{Installs the `inline_forms` CLI and scaffolds opinionated Rails apps with Devise, CanCan, PaperTrail, and optional example data.}
  s.licenses    = ["MIT"]
  s.required_ruby_version = ">= 3.2.0"

  s.files         = InlineFormsGemFiles.gem_files(include_installer: true)
  s.executables   = ["inline_forms"]
  s.require_paths = ["lib"]

  s.add_dependency("rvm", ">= 1.11", "< 2.0")
  s.add_dependency("thor", ">= 1.0", "< 2.0")
end
