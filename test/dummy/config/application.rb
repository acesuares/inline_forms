# frozen_string_literal: true

# Minimal host app for the engine's integration tests (test/integration/).
# Boots the inline_forms engine against an in-memory SQLite database with the
# host-side gems the engine expects (will_paginate, paper_trail, turbo-rails)
# but without Devise, CanCanCan, Sprockets or ActionText: authorization is
# optional in the engine (cancan_enabled? rescues NameError), tests drive the
# UI through Turbo-Frame requests (the frame layout never renders the
# current_user header), and the asset-precompile initializer skips hosts
# without a pipeline.
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require "inline_forms"
# The schema-GUI engine (separate gem, same repo; on the load path via the
# Gemfile's test group). Its integration tests live in test/integration/.
require "inline_forms_schema_edit"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "inline_forms_dummy_test_secret"
    config.logger = ActiveSupport::Logger.new(File::NULL)
    config.active_support.deprecation = :stderr
    config.action_controller.allow_forgery_protection = false
    # Schema is defined by test/integration_test_helper.rb on the in-memory DB.
    config.active_record.maintain_test_schema = false
    # Raise in-place so integration failures carry the real backtrace.
    config.action_dispatch.show_exceptions = :none
  end
end
