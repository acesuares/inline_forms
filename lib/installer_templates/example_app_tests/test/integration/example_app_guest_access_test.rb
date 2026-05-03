# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ExampleAppGuestAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { host!("www.example.com") }

  test "apartments index redirects when not signed in" do
    get apartments_path
    assert_response :redirect
    assert_match %r{/auth/users/sign_in}, @response.redirect_url
  end

  test "root redirects when not signed in" do
    get root_path
    assert_response :redirect
  end
end
