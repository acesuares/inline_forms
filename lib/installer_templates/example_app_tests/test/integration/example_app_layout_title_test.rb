# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# layouts/inline_forms <title> (inline_forms 8.1.53): the installer writes
# `application_name` into config/locales/inline_forms_local.en.yml, and the
# layout falls back to ApplicationHelper#application_name, so the title is
# "<app name> v<version>" — never the html_safe translation_missing span.
class ExampleAppLayoutTitleTest < ExampleAppIntegrationTestCase
  def page_title
    @response.body[%r{<title>(.*?)</title>}m, 1]
  end

  def expected_title
    "#{ERB::Util.h(ApplicationController.helpers.application_name)} v#{InlineForms::VERSION}"
  end

  test "installer defines the en application_name translation" do
    assert I18n.exists?(:application_name, :en)
    assert_equal ApplicationController.helpers.application_name, I18n.t(:application_name, locale: :en)
  end

  test "apartments page title is the app name and version" do
    get apartments_path

    assert_response :success
    assert_equal expected_title, page_title
  end

  test "file trash page title is the app name and version" do
    get "/file_trash"

    assert_response :success
    assert_equal expected_title, page_title
  end

  test "title in nl falls back to the app name, not a placeholder" do
    admin = User.find_by!(email: "admin@example.com")
    nl = Locale.find_or_create_by!(name: "nl") { |l| l.title = "Nederlands" }
    admin.update!(locale: nl)
    sign_in admin

    get apartments_path

    assert_response :success
    assert_includes @response.body, %(<html lang="nl">)
    assert_equal expected_title, page_title
  ensure
    en = Locale.find_by(name: "en")
    admin&.update!(locale: en) if en
  end
end
