# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# The installer enables assume_ssl/force_ssl in the generated production
# config (8.1.36): generated apps deploy behind an SSL-terminating proxy and
# the Devise mailer config assumes https. Guards Brakeman's ForceSSL check
# (the full-gate CI scans this app) against a silent regression, e.g. the
# Rails template shifting its comment format so the installer's gsub misses.
class ExampleAppProductionSslTest < ExampleAppIntegrationTestCase
  test "production config forces SSL" do
    config = File.read(Rails.root.join("config", "environments", "production.rb"))

    assert_match(/^\s*config\.assume_ssl = true/, config,
      "expected the installer to enable config.assume_ssl in production.rb")
    assert_match(/^\s*config\.force_ssl = true/, config,
      "expected the installer to enable config.force_ssl in production.rb")
  end
end
