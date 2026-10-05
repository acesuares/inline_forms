# frozen_string_literal: true

require "test_helper"

# The sign-in page (inline_forms 8.1.57): the Devise layout declares the page
# language like the inline_forms layout, and the submit button is translated
# (it was `f.submit :login`, an untranslated "login" in every locale).
class ExampleAppDeviseSignInTest < ActionDispatch::IntegrationTest
  setup do
    host!("www.example.com")
    @mapping = Devise.mappings.values.first
  end

  def sign_in_path
    Rails.application.routes.url_helpers.public_send("new_#{@mapping.name}_session_path")
  end

  test "the sign-in page declares its language and translates the submit button" do
    get sign_in_path

    assert_response :success
    assert_includes @response.body, %(<html lang="#{I18n.locale}">)
    assert_includes @response.body, %(value="#{I18n.t('inline_forms.devise.login')}")
  end

  test "the submit label has an nl translation" do
    assert_equal "inloggen", I18n.t("inline_forms.devise.login", locale: :nl)
  end
end
