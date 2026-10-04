# frozen_string_literal: true

require_relative "../integration_test_helper"

# layouts/inline_forms <title>: t('application_name') used to render the
# html_safe <span class="translation_missing"> into <title> when the host had
# no translation (every page of a fresh example app). It now falls back to
# ApplicationHelper#application_name ("Dummy" here) and is always plain text.
class LayoutTitleTest < InlineFormsIntegrationTestCase
  teardown do
    I18n.backend.reload!
  end

  def page_title
    response.body[%r{<title>(.*?)</title>}m, 1]
  end

  test "title falls back to the application_name helper without a translation" do
    get widgets_path

    assert_response :success
    assert_equal "Dummy v#{InlineForms::VERSION}", page_title
    refute_includes page_title, "translation_missing"
  end

  test "title uses the application_name translation when the host defines one" do
    I18n.backend.store_translations(:en, application_name: "Widget Works")

    get widgets_path

    assert_response :success
    assert_equal "Widget Works v#{InlineForms::VERSION}", page_title
  end

  test "title in nl does not show the gem's old placeholder" do
    I18n.with_locale(:nl) do
      original = I18n.default_locale
      I18n.default_locale = :nl
      get widgets_path
    ensure
      I18n.default_locale = original
    end

    assert_response :success
    assert_equal "Dummy v#{InlineForms::VERSION}", page_title
  end

  test "markup in the translation is escaped, never rendered into the title" do
    I18n.backend.store_translations(:en, application_name: "<b>Bold</b>")

    get widgets_path

    assert_response :success
    assert_equal "&lt;b&gt;Bold&lt;/b&gt; v#{InlineForms::VERSION}", page_title
  end
end
