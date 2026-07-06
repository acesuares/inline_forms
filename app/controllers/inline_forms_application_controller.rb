# -*- encoding : utf-8 -*-
class InlineFormsApplicationController < ActionController::Base
  protect_from_forgery
  # `layout 'devise' if :devise_controller?` was wrong: `:devise_controller?` is a
  # Symbol (always truthy), so every controller used the Devise layout. Use a
  # callable so only Devise controllers get `layouts/devise`; everything else
  # defaults to `layouts/inline_forms` (actions may still override via `render`).
  layout ->(controller) { controller.devise_controller? ? "devise" : "inline_forms" }

  # NOTE (8.1.31): this class no longer clobbers I18n.available_locales.
  # It used to hard-assign `[ :en, :nl, :pp ]` at class-load time, which ran
  # *after* the host app's initializers in development (classes load lazily)
  # and silently stomped any `config.i18n.available_locales` the app set.
  # Configure available locales in the app: config/application.rb
  #   config.i18n.available_locales = [:en, :nl, :pp]

  #set the locale based on the subdomain
  def set_locale
    I18n.locale = extract_locale_from_subdomain || I18n.default_locale
  end

  # Get locale code from request subdomain (like http://it.application.local:3000)
  def extract_locale_from_subdomain
    locale = request.subdomains.first
    return nil if locale.nil?
    I18n.available_locales.include?(locale.to_sym) ? locale.to_s : nil
  end

end
