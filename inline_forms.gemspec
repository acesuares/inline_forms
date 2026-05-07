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
  s.summary     = %q{Inline editing of forms. Versions after 6.2.14 are currently broken.}
  s.description = %q{Inline Forms aims to ease the setup of forms that provide inline editing. The field list can be specified in the model. Versions after 6.2.14 are currently broken, and we will post a notice when the gem is good again.}
  s.licenses    = ["MIT"]
  s.required_ruby_version = ">= 3.2.0"

  if File.directory?(File.join(__dir__, ".git"))
    s.files      = `git ls-files`.split("\n")
    s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  else
    s.files = Dir.chdir(__dir__) do
      Dir.glob("**/*", File::FNM_DOTMATCH).reject do |f|
        f.start_with?(".git/", ".bundle/", "pkg/") ||
          f == ".git" || f == ".bundle"
      end
    end
    s.test_files = Dir.chdir(__dir__) do
      Dir.glob("{test,spec,features}/**/*")
    end
  end
  s.executables   = ["inline_forms"]
  s.require_paths = ["lib"]

  s.add_dependency('rvm', '>= 1.11', '< 2.0')
  s.add_dependency('thor', '>= 1.0', '< 2.0')
  s.add_dependency('validation_hints', '>= 0.2', '< 1.0')
  s.add_dependency('rails', '>= 7.0.0', '< 7.1')
  s.add_dependency('rails-i18n', '>= 7.0', '< 8.0')

  s.add_development_dependency("minitest", "~> 5.0")

end
