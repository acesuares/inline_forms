# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Smoke test: layouts load Turbo as an ES module (no Sprockets ESM parse error).
# Step 5 (7.8.0) leaves Turbo Drive at its default (enabled); inline flows use
# `<turbo-frame>` + HTML, not jquery-ujs.
class ExampleAppTurboLayoutTest < ExampleAppIntegrationTestCase
  test "inline_forms layout loads turbo.min.js as an ES module" do
    get apartments_path
    assert_response :success

    assert_match(
      %r{<script\s+type="module">\s*import\s+\{\s*Turbo\s*\}\s+from\s+"[^"]*turbo\.min(?:-[a-f0-9]+)?\.js"}m,
      @response.body,
      "expected the inline_forms layout to import turbo.min.js as a module"
    )

    refute_match(
      /Turbo\.session\.drive\s*=\s*false/,
      @response.body,
      "Step 5 enables Turbo Drive by default; disabling it would regress full-page Turbo"
    )
  end
end
