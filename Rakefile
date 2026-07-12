require "bundler"
require_relative "lib/inline_forms/version"

Bundler::GemHelper.install_tasks name: "inline_forms"

namespace :installer do
  Bundler::GemHelper.install_tasks name: "inline_forms_installer"
end

namespace :schema_edit do
  # The schema-GUI gem lives in its own subdirectory (own gemspec, own pkg/).
  Bundler::GemHelper.install_tasks dir: File.expand_path("inline_forms_schema_edit", __dir__),
                                   name: "inline_forms_schema_edit"
end

def inline_forms_pkg_gems
  version = InlineForms::VERSION
  { "inline_forms" => "pkg",
    "inline_forms_installer" => "pkg",
    "inline_forms_schema_edit" => "inline_forms_schema_edit/pkg" }.map do |name, pkg|
    path = File.expand_path(File.join(pkg, "#{name}-#{version}.gem"), __dir__)
    raise "Missing #{path}. Run rake build:all first." unless File.file?(path)
    path
  end
end

def validation_hints_pkg_gem
  version = InlineForms::VERSION
  [
    File.expand_path("../validation_hints/pkg/validation_hints-#{version}.gem", __dir__),
    File.expand_path("~/code/validation_hints/pkg/validation_hints-#{version}.gem")
  ].find { |path| File.file?(path) }
end

desc "Build inline_forms, inline_forms_installer and inline_forms_schema_edit"
task "build:all" => [ "build", "installer:build", "schema_edit:build" ]

desc "Install freshly built gems from pkg/ into the current gemset (required before inline_forms create)"
task "install:local" => [ "build:all" ] do
  gems = inline_forms_pkg_gems
  vh = validation_hints_pkg_gem
  gems << vh if vh
  sh "gem install #{gems.shelljoin}"
  puts "Installed: #{gems.map { |g| File.basename(g) }.join(', ')}"
  puts "Verify: inline_forms --version 2>/dev/null || gem which inline_forms_installer"
end

# Release inline_forms + inline_forms_installer + inline_forms_schema_edit
# (build, git tag/push, RubyGems push). Does not run inline_forms create,
# MyApp, or tests. validation_hints is a separate repo:
# cd ../validation_hints && rake release (same version number).
desc "Release inline_forms, inline_forms_installer and inline_forms_schema_edit to RubyGems (no app generation)"
task "release:all" => [
  "build:all",
  "release:guard_clean",
  "release:source_control_push",
  "release:rubygem_push",
  "installer:release:rubygem_push",
  "schema_edit:release:rubygem_push"
]

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = true
end

task default: :test
