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

  # The gem's title keys are lambdas (lib/locales/inline_forms_titles.rb);
  # a host's own translation of one must load after them to win.
  test "the host's locale files load after the gem's title keys" do
    paths = I18n.load_path.map(&:to_s)
    gem_titles = paths.index { |path| path.end_with?("lib/locales/inline_forms_titles.rb") }
    host = paths.index { |path| path.end_with?("config/locales/inline_forms_local.en.yml") }

    assert gem_titles, "the gem's title keys are on the load path"
    assert host, "the installer's locale file is on the load path"
    assert_operator gem_titles, :<, host
  end

  test "the title keys say the app name in en and nl" do
    name = ApplicationController.helpers.application_name
    %i[en nl].each do |locale|
      assert_equal name, I18n.t("inline_forms.general.application_title", locale: locale)
      assert_equal name, I18n.t("inline_forms.devise.title_for_devise", locale: locale)
    end
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
    assert_includes @response.body, %(<html lang="nl" class="no-js">)
    assert_equal expected_title, page_title
  ensure
    en = Locale.find_by(name: "en")
    admin&.update!(locale: en) if en
  end
end
