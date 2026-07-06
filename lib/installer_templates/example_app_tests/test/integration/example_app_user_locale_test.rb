# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Per-user locale (inline_forms 8.1.31): ApplicationController#switch_locale
# wraps every request in I18n.with_locale(current_user.locale.name), falling
# back to the default for unknown/blank names. Observable via the layout's
# <html lang="..."> attribute.
class ExampleAppUserLocaleTest < ExampleAppIntegrationTestCase
  test "html lang reflects the default locale" do
    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<html lang="en">)
  end

  test "user locale preference switches I18n for the request" do
    admin = User.find_by!(email: "admin@example.com")
    nl = Locale.find_or_create_by!(name: "nl") { |l| l.title = "Nederlands" }
    admin.update!(locale: nl)
    sign_in admin

    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<html lang="nl">)
  ensure
    en = Locale.find_by(name: "en")
    admin&.update!(locale: en) if en
  end

  test "unknown locale name falls back to the default" do
    admin = User.find_by!(email: "admin@example.com")
    xx = Locale.find_or_create_by!(name: "xx") { |l| l.title = "Not a locale" }
    admin.update!(locale: xx)
    sign_in admin

    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<html lang="en">)
  ensure
    en = Locale.find_by(name: "en")
    admin&.update!(locale: en) if en
  end
end
