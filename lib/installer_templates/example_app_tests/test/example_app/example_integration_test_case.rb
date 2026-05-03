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

  def example_app_admin_user
    @example_app_admin_user ||= begin
      locale = Locale.find_or_create_by!(name: "en") { |l| l.title = "English" }
      role = Role.find_or_create_by!(name: "superadmin") { |r| r.description = "Super Admin" }
      user = User.find_or_initialize_by(email: "admin@example.com")
      if user.new_record?
        user.assign_attributes(
          name: "Admin",
          password: "admin999",
          password_confirmation: "admin999",
          locale: locale
        )
        user.save!
      end
      user.roles << role unless user.roles.where(id: role.id).exists?
      user
    end
  end
end
