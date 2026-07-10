# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Devise/role stand-in. The full `layouts/inline_forms` chrome (rendered by
  # create/new HTML responses) calls `current_user.name` and
  # `current_user.role?`, so a nil current_user cannot render it. The stub is
  # superadmin so `destroy_permitted?` allows hard destroy, matching the
  # generated apps' test user.
  DummyUser = Struct.new(:id, :name) do
    def role?(role)
      role.to_sym == :superadmin
    end
  end

  helper_method :current_user

  def current_user
    @current_user ||= DummyUser.new(1, "Dummy User")
  end

  def devise_controller?
    false
  end
end
