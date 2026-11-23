# frozen_string_literal: true

# Base class for integration tests shipped only with `inline_forms create … --example`.
# See test/integration/example_app_*_test.rb
require "test_helper"
require "devise/test/integration_helpers"

class ExampleAppIntegrationTestCase < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    host!("www.example.com")
    sign_in(example_app_admin_user)
  end

  private

  # User 1, the one superadmin (test/test_helpers/the_superadmin.rb).
  def example_app_admin_user
    @example_app_admin_user ||= TheSuperadmin.user
  end
end
