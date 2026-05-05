# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Smoke test for rollout step 1 of stuff/ujs-to-turbo.md (gem-side):
# the layout loads Turbo as an ES module and disables Drive so existing
# UJS-driven links/forms keep working unchanged. If this asserts ever
# fails, frame/stream conversions in later slices will silently fall
# back to full-page navigation (Turbo not loaded) instead of using the
# `<turbo-frame>` fast path.
class ExampleAppTurboLayoutTest < ExampleAppIntegrationTestCase
  test "inline_forms layout loads turbo.min.js as an ES module with drive disabled" do
    get apartments_path
    assert_response :success

    assert_match(
      %r{<script\s+type="module">\s*import\s+\{\s*Turbo\s*\}\s+from\s+"[^"]*turbo\.min(?:-[a-f0-9]+)?\.js"}m,
      @response.body,
      "expected the inline_forms layout to import turbo.min.js as a module"
    )

    assert_match(
      /Turbo\.session\.drive\s*=\s*false/,
      @response.body,
      "expected Turbo.session.drive = false so existing UJS keeps working"
    )
  end
end
