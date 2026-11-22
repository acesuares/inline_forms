# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Production minifies JavaScript with terser on mini_racer (8.1.69; uglifier
# before, which nothing switched on and which cannot parse Turbo 8's ES2022).
# The test env does not load the production group, so this reads the generated
# files; a real assets:precompile is checked by hand on a release.
class ExampleAppProductionJsCompressorTest < ExampleAppIntegrationTestCase
  test "production config sets the terser compressor" do
    config = File.read(Rails.root.join("config", "environments", "production.rb"))

    assert_match(/^  config\.assets\.js_compressor = :terser$/, config,
      "expected the installer to set js_compressor in production.rb")
  end

  test "the production group has terser and mini_racer, and uglifier is gone" do
    gemfile = File.read(Rails.root.join("Gemfile"))
    production = gemfile[/^group :production do\n(.*?)^end/m, 1]

    assert production, "expected a production group in the Gemfile"
    assert_match(/gem ["']terser["']/, production)
    assert_match(/gem ["']mini_racer["']/, production)
    assert_no_match(/gem ["']uglifier["']/, gemfile)
  end
end
