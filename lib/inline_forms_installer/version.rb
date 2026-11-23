# -*- encoding : utf-8 -*-

module InlineFormsInstaller
  VERSION = "8.1.77"

  # Canonical bare Ruby version (the gemspecs accept any Ruby >= 4.0.0; an app
  # gets the running Ruby when this one is not there, see ruby_for_app).
  # Written verbatim into generated apps' `.ruby-version` for rbenv/chruby/asdf/
  # mise (which need the bare `X.Y.Z` form). For RVM installs the Creator writes
  # the `ruby-X.Y.Z` form instead, because RVM's `.ruby-version` reader rejects a
  # bare version. See Creator#create (ENV["ruby_version"]).
  TARGET_RUBY_VERSION = "4.0.10"

  # Kept in sync with inline_forms gem releases from the same repo tag.
  INLINE_FORMS_VERSION = VERSION
end
