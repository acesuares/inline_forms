class InlineFormsApplicationController < ActionController::Base
  protect_from_forgery
  layout 'devise' if :devise_controller?
  
  # limit available locales by setting this. Override in applicaton_controller.
  I18n.available_locales = [ :en, :nl, :pp ]

  def set_locale
    I18n.locale = extract_locale_from_subdomain.to_sym || I18n.default_locale
  end

  # Get locale code from request subdomain (like http://it.application.local:3000)
  def extract_locale_from_subdomain
    locale = request.subdomains.first
    return nil if locale.nil?
    I18n.available_locales.include?(locale.to_sym) ? locale : nil
  end

end
