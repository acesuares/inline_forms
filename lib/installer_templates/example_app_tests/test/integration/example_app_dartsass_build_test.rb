# frozen_string_literal: true

require "test_helper"
require "dartsass/runner"
require "sass-embedded"

# config/initializers/inline_forms_dartsass_builds.rb puts the gem's
# stylesheet dir first on the Sass load path. Without it,
# app/assets/builds (ahead of the gem in config.assets.paths) shadows the
# gem's .scss: `@use "inline_forms/inline_forms"` in the
# inline_forms_install/*_main.scss entries re-imports the app's previous
# compiled CSS, and gem stylesheet changes never reach the app after its
# first build. test_helper runs dartsass:build, so by now builds/ already held
# a previous build when this run's one ran.
class ExampleAppDartsassBuildTest < ActiveSupport::TestCase
  test "the gem stylesheet dir is the first Sass load path" do
    command = Dartsass::Runner.dartsass_compile_command
    first_load_path = command.index { |arg| arg == "--load-path" || arg.start_with?("--load-path=") }

    # Two arguments, so a gem path with a space stays one argument.
    assert_equal [ "--load-path", gem_stylesheets ], command[first_load_path, 2]
  end

  %w[inline_forms devise].each do |entry|
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
