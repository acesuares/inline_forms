# frozen_string_literal: true

require "test_helper"
require "sass-embedded"

# The inline_forms_install/*_main.scss entries `@use` the gem's stylesheets
# with an explicit .scss extension (config/initializers/
# inline_forms_dartsass_builds.rb). Without it app/assets/builds (ahead of the
# gem on the Sass load path) shadows the gem's .scss: a bare
# `@use "inline_forms/inline_forms"` re-imports the app's previous compiled
# CSS, and gem stylesheet changes never reach the app after its first build.
# test_helper runs dartsass:build, so by now builds/ already held a previous
# build when this run's one ran.
class ExampleAppDartsassBuildTest < ActiveSupport::TestCase
  test "the initializer no longer patches dartsass-rails' load paths" do
    code = Rails.root.join("config/initializers/inline_forms_dartsass_builds.rb").readlines
                .reject { |line| line.lstrip.start_with?("#") }.join

    refute_includes code, "Dartsass::Runner"
  end

  %w[inline_forms devise].each do |entry|
    test "inline_forms_install/#{entry}_main.scss uses the gem's #{entry}.scss with its extension" do
      main = Rails.root.join("app/assets/stylesheets/inline_forms_install/#{entry}_main.scss").read

      assert_includes main, %(@use "inline_forms/#{entry}.scss" as *;)
    end

    test "builds/inline_forms/#{entry}.css is compiled from the gem's #{entry}.scss" do
      built = Rails.root.join("app/assets/builds/inline_forms/#{entry}.css")
      assert built.file?, "#{built} missing; dartsass:build did not run"

      expected = Sass.compile(File.join(gem_stylesheets, "inline_forms", "#{entry}.scss"),
                              load_paths: load_paths, style: :compressed,
                              logger: Sass::Logger.silent).css
      assert_equal expected.strip, built.read.strip,
        "#{entry}.css differs from a direct compile of the gem's #{entry}.scss " \
        "(re-imported a stale app/assets/builds/inline_forms/#{entry}.css?)"
    end
  end

  private

  def gem_stylesheets
    InlineForms::Engine.root.join("app/assets/stylesheets").to_s
  end

  # The gem's stylesheets, then the app's asset paths without app/assets/builds.
  def load_paths
    [ gem_stylesheets ] + Rails.application.config.assets.paths.map(&:to_s)
                                .reject { |path| path.end_with?("app/assets/builds") }
  end
end
