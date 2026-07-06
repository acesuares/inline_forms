# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Devise stand-ins: the engine only touches current_user in the full
  # `layouts/inline_forms` chrome (header) and via PaperTrail's whodunnit,
  # both of which tolerate nil. Integration tests use Turbo-Frame requests,
  # which render through the minimal turbo_rails/frame layout.
  helper_method :current_user

  def current_user
    nil
  end

  def devise_controller?
    false
  end
end
