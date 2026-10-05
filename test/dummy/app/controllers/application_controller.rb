# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Devise/role stand-in. The full `layouts/inline_forms` chrome (rendered by
  # create/new HTML responses) calls `current_user.name` and
  # `current_user.role?`, so a nil current_user cannot render it. The stub is
  # superadmin so `destroy_permitted?` allows hard destroy, matching the
  # generated apps' test user. A test can switch that off with
  # dummy_user_superadmin (reset in InlineFormsIntegrationTestCase#setup).
  mattr_accessor :dummy_user_superadmin, default: true

  DummyUser = Struct.new(:id, :name) do
    def role?(role)
      role.to_sym == :superadmin && ApplicationController.dummy_user_superadmin
    end
  end

  helper_method :current_user

  # Generated apps redirect HTML with a notice; a bare 403 is easier to assert.
  rescue_from CanCan::AccessDenied do
    head :forbidden
  end

  def current_user
    @current_user ||= DummyUser.new(1, "Dummy User")
  end

  def devise_controller?
    false
  end
end
