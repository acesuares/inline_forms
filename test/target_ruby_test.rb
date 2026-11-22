# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require_relative "../lib/inline_forms_installer/target_ruby"

class TargetRubyTest < Minitest::Test
  TARGET = InlineFormsInstaller::TARGET_RUBY_VERSION

  def test_the_target_when_it_runs_the_installer
    assert_equal(TARGET, InlineFormsInstaller.ruby_for_app(running: TARGET))
  end

  def test_the_running_ruby_when_the_target_is_not_there
    assert_equal("4.0.4", InlineFormsInstaller.ruby_for_app(running: "4.0.4"))
    assert_equal("4.1.2", InlineFormsInstaller.ruby_for_app(running: "4.1.2"))
  end

  def test_the_target_when_rvm_has_it
    Dir.mktmpdir do |rvm_path|
      assert_equal("4.0.4", InlineFormsInstaller.ruby_for_app(running: "4.0.4", rvm_path: rvm_path))

      FileUtils.mkdir_p(File.join(rvm_path, "rubies", "ruby-#{TARGET}"))
      assert_equal(TARGET, InlineFormsInstaller.ruby_for_app(running: "4.0.4", rvm_path: rvm_path))
    end
  end

  def test_older_than_the_target
    assert(InlineFormsInstaller.older_than_target_ruby?("4.0.4"))
    refute(InlineFormsInstaller.older_than_target_ruby?(TARGET))
    refute(InlineFormsInstaller.older_than_target_ruby?("4.1.0"))
  end
end
