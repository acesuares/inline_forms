# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Pattern 1 preset theming (inline_forms 8.1.29): the user's integer `theme`
# column maps to a `theme-<name>` body class; palettes live in the engine's
# _theme.scss as --if-color-* custom-property overrides.
class ExampleAppUserThemeTest < ExampleAppIntegrationTestCase
  test "body carries the default theme class" do
    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<body class="theme-default">)
  end

  test "user theme preference switches the body class" do
    admin = User.find_by!(email: "admin@example.com")
    admin.update!(theme: 1)
    # Warden's test login caches the user *object* from setup's sign_in;
    # re-sign-in so current_user carries the updated theme.
    sign_in admin

    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<body class="theme-dark">)
  ensure
    admin&.update!(theme: 0)
  end

  test "high-contrast maps the css-safe class name" do
    admin = User.find_by!(email: "admin@example.com")
    admin.update!(theme: 3)
    sign_in admin

    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<body class="theme-high-contrast">)
  ensure
    admin&.update!(theme: 0)
  end

  test "theme dropdown renders on the user show panel" do
    admin = User.find_by!(email: "admin@example.com")
    frame = "user_#{admin.id}"

    get user_path(admin, update: frame),
        headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="user_#{admin.id}_theme">)
  end
end
