# frozen_string_literal: true

require "open3"
require_relative "../example_app/example_integration_test_case"

# bin/ci runs these commands; the installer supplies their gems (8.1.71, 8.1.72).
# Only whether they start is checked here. bundler-audit needs the network
# (advisory database), and what Brakeman and RuboCop report depends on the newest
# version: a style rule must not make `inline_forms create --example`
# fail. The full gate runs bin/ci, with all three.
class ExampleAppSecurityToolsTest < ExampleAppIntegrationTestCase
  test "bin/brakeman starts" do
    assert_tool_starts "bin/brakeman", "--version"
  end

  test "bin/bundler-audit starts" do
    assert_tool_starts "bin/bundler-audit", "version"
  end

  test "bin/rubocop starts" do
    assert_tool_starts "bin/rubocop", "--version"
  end

  # They are for development; the production image must not get them (8.1.76).
  test "the tools are in the development group only" do
    gemfile = File.read(Rails.root.join("Gemfile"))
    development = gemfile.scan(/^group :development do\n(.*?)^end/m).join

    %w[brakeman bundler-audit rubocop-rails-omakase].each do |gem_name|
      assert_match(/gem "#{gem_name}"/, development)
      assert_equal 1, gemfile.scan(/gem "#{gem_name}"/).size, gem_name
    end
  end

  # bin/ci would go red whenever a newer Brakeman is released (8.1.76).
  test "bin/brakeman does not insist on the latest Brakeman" do
    assert_no_match(/ensure-latest/, File.read(Rails.root.join("bin/brakeman")))
  end

  # GitHub runs nothing; bin/ci is for the developer and for any other CI (8.1.76).
  test "no GitHub workflows or Dependabot, but bin/ci" do
    assert_not File.exist?(Rails.root.join(".github"))
    assert File.executable?(Rails.root.join("bin/ci"))
    assert File.exist?(Rails.root.join("config/ci.rb"))
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
