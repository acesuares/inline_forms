# frozen_string_literal: true

require "open3"
require_relative "../example_app/example_integration_test_case"

# bin/ci runs these commands; the installer supplies their gems (8.1.71, 8.1.72).
# Only whether Brakeman and bundler-audit start is checked here: their scans need
# the network (latest Brakeman, advisory database), so those stay with bin/ci and
# the full gate. RuboCop needs neither, so it checks the whole app: what the
# generators write has to be clean.
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

  # It would download npm packages into the app; nothing needs it (8.1.75).
  test "importmap is not there" do
    assert_not File.exist?(Rails.root.join("bin/importmap"))
    assert_not File.exist?(Rails.root.join("config/importmap.rb"))
    %w[Gemfile.lock config/ci.rb].each do |file|
      assert_no_match(/importmap/i, File.read(Rails.root.join(file)), file)
    end
  end

  private

  def assert_tool_starts(*command)
    output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)

    assert status.success?, "expected #{command.join(" ")} to run:\n#{output}"
  end
end
