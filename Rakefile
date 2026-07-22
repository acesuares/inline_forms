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
# Release git-push ALWAYS targets `origin` (GitHub) only.
#
# Do NOT use Bundler's stock `release:source_control_push`: it pushes to the
# CURRENT BRANCH's tracking remote (`git config branch.<branch>.remote`).
# Feature branches in this repo track `forgejo` (dev02) because that's where
# CI runs, so a release cut from a feature branch would push the release commit
# and version tag to forgejo instead of GitHub. `origin` is the only place
# release commits/tags belong; `forgejo` is CI-only. This task is also
# idempotent on the tag, so a re-run after a failed push still lands the tag on
# origin (Bundler's version skips entirely once the tag exists locally).
# Also override the bare `release` task (from install_tasks above) so a stray
# `rake release` can't push to a feature branch's forgejo tracking remote
# either. The intended entry point is `release:all`, but this closes the
# footgun on both.
Rake::Task["release"].clear if Rake::Task.task_defined?("release")
desc "Build inline_forms, tag, push to origin (GitHub) and push the gem to RubyGems"
task "release" => [ "build", "release:guard_clean",
                    "release:push_to_origin", "release:rubygem_push" ]

desc "Tag the release and push the commit + tag to origin (GitHub) only"
task "release:push_to_origin" do
  version = InlineForms::VERSION
  tag     = "v#{version}"
  branch  = `git rev-parse --abbrev-ref HEAD`.strip
  unless system("git", "rev-parse", "-q", "--verify", "refs/tags/#{tag}",
                out: File::NULL, err: File::NULL)
    sh "git", "tag", tag
  end
  sh "git", "push", "origin", "refs/heads/#{branch}"
  sh "git", "push", "origin", "refs/tags/#{tag}"
end

desc "Release inline_forms, inline_forms_installer and inline_forms_schema_edit to RubyGems (no app generation)"
task "release:all" => [
  "build:all",
  "release:guard_clean",
  "release:push_to_origin",
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
