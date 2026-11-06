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

# SELF-IMPORT GUARD: the two inline_forms_install/*_main.scss entries `@use`
# the gem's stylesheets WITH their .scss extension. dartsass-rails passes
# app/assets/stylesheets and then every config.assets.paths entry as a
# --load-path, app/assets/builds comes before the gem, and a plain .css file
# is importable by Sass: a bare `@use "inline_forms/inline_forms"` resolved to
# the PREVIOUS OUTPUT app/assets/builds/inline_forms/inline_forms.css, so from
# the second build on each build re-imported its own stale result and gem
# stylesheet changes never reached the app. With the extension Dart Sass only
# takes a .scss file (the gem's), and the build fails loudly if the gem ever
# renames it. (Until 8.1.66 this file prepended the gem dir to
# Dartsass::Runner.dartsass_load_paths, an internal of dartsass-rails.)
