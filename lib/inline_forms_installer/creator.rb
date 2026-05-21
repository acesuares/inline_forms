# -*- encoding : utf-8 -*-
require "securerandom"
require "thor"

module InlineFormsInstaller
  class Creator < Thor
    include Thor::Actions

    def self.exit_on_failure?
      true
    end

    def self.source_root
      gem_root
    end

    desc "create APP", "create an application with inline_forms v#{InlineFormsInstaller.inline_forms_version}"
    DATABASE_OPTIONS = %w(sqlite mysql)
    method_option :database, :aliases => "-d", :banner => DATABASE_OPTIONS.join("|"), :desc => "specify development database"
    method_option :example, :type => :boolean, :desc => "install the example app. uses sqlite as development database"
    method_option :email, :aliases => "-e", :default => "admin@example.com", :desc => "specify admin email"
    method_option :password, :aliases => "-p", :default => "admin999", :desc => "specify admin password"
    method_option :runtest, :aliases => "--run-test", :default => false, :desc => "run tests"
    method_option :skiprvm, :aliases => "--no-rvm", :type => :boolean, :default => false, :desc => "install inline_forms without RVM"

    def create(app_name)
      def self.skiprvm
        options[:skiprvm]
      end

      def self.runtest
        options[:runtest]
      end

      def self.install_example?
        options[:example]
      end

      def self.database
        @database ||= options[:database]
        return @database if DATABASE_OPTIONS.include?(@database)
        say "No Database specified please choose one database #{DATABASE_OPTIONS.join(' | ')}", :red
        while !DATABASE_OPTIONS.include?(@database)
          @database = ask "Database: "
          return @database if DATABASE_OPTIONS.include?(@database)
        end
      end

      def self.using_sqlite?
        database == "sqlite"
      end

      def self.email
        options[:email]
      end

      def self.password
        options[:password]
      end

      if install_example? && !using_sqlite?
        say "--example can only be used with an sqlite development database", :red
        exit 1
      end

      inline_forms_version = InlineFormsInstaller.inline_forms_version
      say "Creating #{app_name} with inline_forms v#{inline_forms_version} and development database #{database}...", :green

      regex = /\A[0-9a-zA-Z][0-9a-zA-Z_-]+[0-9a-zA-Z]\Z/
      if !regex.match(app_name)
        say "Error: APP must match #{regex.source}", :red
        exit 1
      end

      if File.exist?(app_name)
        say "Error: APP exists", :red
        exit 1
      end

      target_ruby = InlineFormsInstaller::TARGET_RUBY_VERSION
      require "rvm"
      if RVM.current && !options[:skiprvm]
        say "Installing inline_forms with RVM", :green
      else
        say "Installing inline_forms without RVM", :green
      end

      say "Installing with #{options[:database]}", :green

      options.each do |k, v|
        ENV[k] = v.to_s
      end

      ENV["using_sqlite"] = using_sqlite?.to_s
      ENV["database"] = database
      ENV["install_example"] = install_example?.to_s
      ENV["ruby_version"] = target_ruby
      ENV["inline_forms_rvm_gemset"] = app_name if RVM.current && !options[:skiprvm]
      ENV["inline_forms_version"] = inline_forms_version
      ENV["inline_forms_installer_version"] = InlineFormsInstaller::VERSION
      ENV["INLINE_FORMS_INSTALLER_ROOT"] = InlineFormsInstaller.gem_root
      ENV["INLINE_FORMS_ROOT"] = InlineFormsInstaller.inline_forms_gem_root

      app_template_file = File.join(__dir__, "app_template.rb")

      require "rubygems"
      compatible_rails =
        begin
          Gem::Specification
            .find_all_by_name("rails")
            .map(&:version)
            .select { |v| v >= Gem::Version.new("7.2") && v < Gem::Version.new("7.3") }
            .max
        rescue StandardError
          nil
        end
      rails_invocation = compatible_rails ? "rails _#{compatible_rails}_" : "rails"
      say "Generating app with: #{rails_invocation} new ...", :green

      unless run("#{rails_invocation} new #{app_name} -m #{app_template_file} --skip-bundle --skip-bootsnap --javascript=importmap")
        say "Rails could not create the app '#{app_name}', maybe because it is a reserved word...", :red
        exit 1
      end

      say "Created #{app_name}. Before running Rails, use the app's RVM gemset and Bundler:", :green
      say "  cd #{app_name}", :green
      say "  rvm use .", :green
      say "  bundle install", :green
      say "  bundle exec rails test", :green
    end
  end
end

Signal.trap("INT") { puts; exit }
