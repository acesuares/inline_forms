# frozen_string_literal: true

# Dart Sass entrypoints for this app (see dartsass-rails). Output lives under
# app/assets/builds/; Sprockets must not link any .scss (only compiled .css).
#
# Visual reference (chrome widths, bars, jQuery UI sunny, Foundation Icons):
#   foundation-rails ~> 6.6.2 + sass-rails (sassc) — last stack verified in-repo.
# Upgraded stack (this file):
#   foundation-rails ~> 6.9 (RubyGems 6.9.0.x) + dartsass-rails (Dart Sass).
Rails.application.config.dartsass.builds = {
  "application.scss" => "application.css",
  "inline_forms_install/inline_forms_main.scss" => "inline_forms/inline_forms.css",
  "inline_forms_install/devise_main.scss" => "inline_forms/devise.css"
}
