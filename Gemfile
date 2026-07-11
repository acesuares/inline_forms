source "https://rubygems.org"

gemspec name: "inline_forms"

# Local sibling until validation_hints 8.0.0 is on RubyGems (maintainer dev only).
gem "validation_hints", path: "../validation_hints"

# test/dummy host-app stand-ins: the engine expects the host to supply these
# (generated apps get them from the installer Gemfile). Used only by the
# integration tests under test/integration/.
group :test do
  gem "sqlite3", ">= 2.1"
  gem "will_paginate", "~> 4.0"
  gem "paper_trail", "~> 17.0"
  gem "turbo-rails"
  # The schema-GUI engine gem (same repo, own gemspec). Test group so the
  # dummy app's `Bundler.require(*Rails.groups)` loads it and the engine's
  # schema_gui integration tests exercise the extracted controller/views.
  gem "inline_forms_schema_gui", path: "inline_forms_schema_gui"
end

group :development, :test do
  # Rails omakase style; offenses grandfathered in .rubocop_todo.yml.
  gem "rubocop-rails-omakase", require: false
end
