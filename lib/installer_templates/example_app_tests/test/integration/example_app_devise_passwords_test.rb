# frozen_string_literal: true

require "test_helper"

# Devise 5 removed `devise_error_messages!`; the gem's passwords/new and
# passwords/edit views still called it, so "Forgot your password?" and the
# reset link both raised (inline_forms 8.1.54). They, and the otherwise unused
# devise/shared/_header_and_errors partial, now render Devise's own
# devise/shared/error_messages partial.
class ExampleAppDevisePasswordsTest < ActionDispatch::IntegrationTest
  setup do
    host!("www.example.com")
    @mapping = Devise.mappings.values.first
  end

  def path(name, **params)
    Rails.application.routes.url_helpers.public_send("#{name.sub('RESOURCE', @mapping.name.to_s)}_path", **params)
  end

  def build_user
    locale = Locale.find_or_create_by!(name: "en") { |l| l.title = "English" }
    @mapping.to.create!(
      email: "reset-#{SecureRandom.hex(4)}@example.com",
      name: "Reset",
      password: "reset9999",
      password_confirmation: "reset9999",
      locale: locale
    )
  end

  test "forgot password page renders" do
    get path("new_RESOURCE_password")

    assert_response :success
    assert_includes @response.body, %(id="inline_forms_devise_form")
  end

  test "unknown email re-renders the form with Devise's error list" do
    post path("RESOURCE_password"),
         params: { @mapping.name => { email: "nobody-#{SecureRandom.hex(4)}@example.com" } }

    assert_response :unprocessable_content
    assert_includes @response.body, %(id="error_explanation")
  end

  test "reset password page renders for a valid token" do
    token = build_user.send(:set_reset_password_token)

    get path("edit_RESOURCE_password", reset_password_token: token)

    assert_response :success
    assert_includes @response.body, %(id="inline_forms_devise_form")
  end

  test "header_and_errors partial shows the app name and the resource errors" do
    resource = @mapping.to.new
    resource.errors.add(:email, "is broken")
    renderer = Devise::PasswordsController.renderer.new("devise.mapping" => @mapping)

    html = renderer.render(partial: "devise/shared/header_and_errors",
                           locals: { resource: resource })

    assert_includes html, %(<div id="large_title">#{ERB::Util.h(ApplicationController.helpers.application_name)}</div>)
    assert_includes html, %(id="error_explanation")
    assert_includes html, "is broken"
    refute_includes html, "translation_missing"
  end
end
