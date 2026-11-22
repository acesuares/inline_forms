# frozen_string_literal: true

require "inline_forms_installer/version"

module InlineFormsInstaller
  # The Ruby a generated app pins in `.ruby-version`: TARGET_RUBY_VERSION when
  # it is there, else the Ruby that runs the installer, so that the app can
  # always find its Ruby. +rvm_path+ is nil without RVM; other version managers
  # cannot be asked reliably.
  def self.ruby_for_app(running: RUBY_VERSION, rvm_path: nil)
    return TARGET_RUBY_VERSION if running == TARGET_RUBY_VERSION
    return TARGET_RUBY_VERSION if rvm_path && File.directory?(File.join(rvm_path, "rubies", "ruby-#{TARGET_RUBY_VERSION}"))

    running
  end

  def self.older_than_target_ruby?(version)
    Gem::Version.new(version) < Gem::Version.new(TARGET_RUBY_VERSION)
  end
end
