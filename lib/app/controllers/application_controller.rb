class ApplicationController < ActionController::Base
  protect_from_forgery
  layout 'devise' if :devise_controller?

  def set_locale
    I18n.locale = extract_locale_from_subdomain || I18n.default_locale
  end

  # Get locale code from request subdomain (like http://it.application.local:3000)
  def extract_locale_from_subdomain
    parsed_locale = request.subdomains.first
    I18n.available_locales.include?(parsed_locale.to_sym) ? parsed_locale : nil
  end

end
