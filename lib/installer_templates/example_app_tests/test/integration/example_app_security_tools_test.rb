# frozen_string_literal: true

require "open3"
require_relative "../example_app/example_integration_test_case"

# `rails new` writes bin/brakeman and bin/bundler-audit and bin/ci runs them;
# the installer's Gemfile supplies the gems (8.1.71). Only whether the binstubs
# start is checked here: a scan needs the network (latest Brakeman, advisory
# database), so that stays with bin/ci and the full gate. RuboCop needs neither,
# so it checks the whole app: what the generators write has to be clean.
class ExampleAppSecurityToolsTest < ExampleAppIntegrationTestCase
  test "bin/brakeman starts" do
    assert_tool_starts "bin/brakeman", "--version"
  end

  test "bin/bundler-audit starts" do
    assert_tool_starts "bin/bundler-audit", "version"
  end

  test "bin/rubocop finds no offenses" do
    assert_tool_starts "bin/rubocop", "--format", "simple"
  end

  private

  def assert_tool_starts(*command)
    output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)

    assert status.success?, "expected #{command.join(" ")} to run:\n#{output}"
  end
end
