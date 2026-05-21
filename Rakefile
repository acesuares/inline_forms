require "bundler"
require_relative "lib/inline_forms/version"

Bundler::GemHelper.install_tasks name: "inline_forms"

namespace :installer do
  Bundler::GemHelper.install_tasks name: "inline_forms_installer"
end

def inline_forms_pkg_gems
  pkg = File.expand_path("pkg", __dir__)
  version = InlineForms::VERSION
  %w[inline_forms inline_forms_installer].map do |name|
    path = File.join(pkg, "#{name}-#{version}.gem")
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

desc "Build both inline_forms and inline_forms_installer into pkg/"
task "build:all" => ["build", "installer:build"]

desc "Install freshly built gems from pkg/ into the current gemset (required before inline_forms create)"
task "install:local" => ["build:all"] do
  gems = inline_forms_pkg_gems
  vh = validation_hints_pkg_gem
  gems << vh if vh
  sh "gem install #{gems.shelljoin}"
  puts "Installed: #{gems.map { |g| File.basename(g) }.join(', ')}"
  puts "Verify: inline_forms --version 2>/dev/null || gem which inline_forms_installer"
end

desc "Release both gems: tag once, push inline_forms and inline_forms_installer to RubyGems"
task "release:all" => [
  "install:local",
  "release:guard_clean",
  "release:source_control_push",
  "release:rubygem_push",
  "installer:release:rubygem_push"
]

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = true
end

task default: :test
