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

# SELF-IMPORT GUARD: put the inline_forms gem's stylesheet dir FIRST on the
# Sass load path. Dartsass::Runner assembles
#   dartsass <build_options> --load-path app/assets/stylesheets
#            --load-path <each config.assets.paths entry> <in:out ...>
# and Dart Sass takes the first load path that has a match. app/assets/builds
# is on config.assets.paths BEFORE the gem, and a plain .css file is importable
# by Sass, so `@use "inline_forms/inline_forms"` (and ".../devise") in the
# inline_forms_install/*_main.scss entries would resolve to the PREVIOUS OUTPUT
# app/assets/builds/inline_forms/{inline_forms,devise}.css instead of the gem's
# .scss: from the second build on, each build re-imports its own stale result
# and gem stylesheet changes never reach the app. build_options precede the
# load paths in the command, so this --load-path wins. Single token on
# purpose: the runner splits every build_options entry on whitespace.
Rails.application.config.dartsass.build_options <<
  "--load-path=#{InlineForms::Engine.root.join('app/assets/stylesheets')}"
