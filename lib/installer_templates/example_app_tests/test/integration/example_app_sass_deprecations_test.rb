# frozen_string_literal: true

require "test_helper"
require "sass-embedded"

# Sass @import is removed in Dart Sass 3. Since 8.1.58 the gem's entry points
# load foundation_and_overrides with @use; the only gem @imports left are the
# three in foundation_and_overrides.scss that wait for the Foundation decision
# (see the module-system note in inline_forms/inline_forms.scss). Compiles
# both entry points from the installed gem, with every deprecation reported
# (verbose), and fails if the gem gains an @import or an entry point compiles
# with more [import] warnings than 8.1.58 had.
class ExampleAppSassDeprecationsTest < ActiveSupport::TestCase
  GEM_IMPORTS_LEFT = [
    "foundation_and_overrides.scss 'settings/settings'",
    "foundation_and_overrides.scss 'foundation'",
    "foundation_and_overrides.scss 'theme'"
  ].freeze
  # 8.1.58 with foundation-rails 6.9.0.0: the three above + 114 inside Foundation.
  MAX_IMPORT_WARNINGS = 117

  %w[inline_forms devise].each do |entry|
    test "#{entry}.scss compiles without new @import deprecations" do
      imports = import_deprecations(entry)

      gem_imports = imports.select { |span| span.url.start_with?(gem_stylesheets_url) }
                           .map { |span| "#{File.basename(span.url)} #{span.text}" }
      assert_empty gem_imports - GEM_IMPORTS_LEFT,
        "#{entry}.scss: new @import in the gem; load it with @use"
      assert_operator imports.size, :<=, MAX_IMPORT_WARNINGS,
        "#{entry}.scss: more [import] deprecations than 8.1.58"
    end
  end

  private

  def gem_stylesheets
    InlineForms::Engine.root.join("app/assets/stylesheets").to_s
  end

  def gem_stylesheets_url
    "file://#{gem_stylesheets}/"
  end

  # The gem's stylesheets first, then the app's asset paths without
  # app/assets/builds (its compiled inline_forms/*.css would shadow the .scss).
  def load_paths
    [ gem_stylesheets ] + Rails.application.config.assets.paths.map(&:to_s)
                                .reject { |path| path.end_with?("app/assets/builds") }
  end

  def import_deprecations(entry)
    spans = []
    logger = {
      warn: lambda do |_message, context|
        spans << context.span if context.deprecation && context.deprecation_type == "import"
      end
    }
    Sass.compile(File.join(gem_stylesheets, "inline_forms", "#{entry}.scss"),
                 load_paths: load_paths, style: :compressed, verbose: true, logger: logger)
    spans
  end
end
