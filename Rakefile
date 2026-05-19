require "bundler"

Bundler::GemHelper.install_tasks name: "inline_forms"

namespace :installer do
  Bundler::GemHelper.install_tasks name: "inline_forms_installer"
end

desc "Build both inline_forms and inline_forms_installer into pkg/"
task "build:all" => ["build", "installer:build"]

desc "Release both gems: tag once, push inline_forms and inline_forms_installer to RubyGems"
task "release:all" => [
  "build:all",
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
