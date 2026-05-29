# -*- encoding : utf-8 -*-
module InlineFormsInstaller
  VERSION = "8.1.19"

  # Canonical bare Ruby version (must match gemspec `required_ruby_version`).
  # Written verbatim into generated apps' `.ruby-version` for rbenv/chruby/asdf/
  # mise (which need the bare `X.Y.Z` form). For RVM installs the Creator writes
  # the `ruby-X.Y.Z` form instead, because RVM's `.ruby-version` reader rejects a
  # bare version. See Creator#create (ENV["ruby_version"]).
  TARGET_RUBY_VERSION = "4.0.4"

  # Kept in sync with inline_forms gem releases from the same repo tag.
  INLINE_FORMS_VERSION = VERSION
end
