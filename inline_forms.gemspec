# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "inline_forms/version"

Gem::Specification.new do |s|
  s.name        = "inline_forms"
  s.version     = InlineForms::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ace Suares"]
  s.email       = ["ace@suares.com"]
  s.homepage    = %q{http://github.com/acesuares/inline_forms}
  s.summary     = %q{Inline editing of forms.}
  s.description = %q{Inline Forms aims to ease the setup of forms that provide inline editing. The field list can be specified in the model.}
  s.licenses    = ["MIT"]

  s.rubyforge_project = "inline_forms"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

#  s.add_runtime_dependency(%q<rails>, ["~> 3.1.0"])
#  s.add_runtime_dependency(%q<rake>, [">= 0"])
#  s.add_runtime_dependency(%q<jquery-rails>, [">= 0"])
#  s.add_runtime_dependency(%q<mysql2>, [">= 0"])
#  s.add_runtime_dependency(%q<capistrano>, [">= 0"])
#  s.add_runtime_dependency(%q<tabs_on_rails>, [">= 0"])
#  s.add_runtime_dependency(%q<carrierwave>, [">= 0"])
#  s.add_runtime_dependency(%q<remotipart>, ["~> 1.0"])
#  s.add_runtime_dependency(%q<paper_trail>, [">= 0"])
#  s.add_development_dependency(%q<rspec-rails>, [">= 0"])
#  s.add_development_dependency(%q<shoulda>, [">= 0"])
#  s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
#  s.add_development_dependency(%q<jeweler>, ["~> 1.5.2"])
#  s.add_development_dependency(%q<rcov>, [">= 0"])

end

