# -*- encoding : utf-8 -*-
require "securerandom"
require "thor"
require_relative "create_log"

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
    method_option :skiprvm, :aliases => "--no-rvm", :type => :boolean, :default => false, :desc => "install inline_forms without RVM"

    def create(app_name)
      def self.skiprvm
        options[:skiprvm]
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

      started_at = Time.now
      log_path = InlineFormsInstaller::CreateLog.final_path(app_name, started_at)
      say "Install log: #{log_path}", :green

      shell_cmd = [
        rails_invocation, "new", app_name, "-m", app_template_file,
        "--skip-bundle", "--skip-bootsnap", "--javascript=importmap"
      ].join(" ")

      ok, log_path = InlineFormsInstaller::CreateLog.tee_rails_new(app_name, shell_cmd, started_at: started_at)
      unless ok
        say "Rails could not create the app '#{app_name}', maybe because it is a reserved word...", :red
        say "Install log: #{log_path}", :red
        exit 1
      end

      print_create_summary(app_name, log_path, started_at, install_example?)
    end

    def test_summary_from_log(log_path, ran_example)
      return "(not run — create without --example)" unless ran_example
      return "(install log missing)" unless log_path.to_s != "" && File.file?(log_path)

      summary = File.read(log_path).lines.reverse.find { |l| l =~ /\d+ runs,/ }
      return summary.strip if summary

      "(see install log — no Minitest summary line)"
    end

    def bundle_check_ok?(app_name)
      app_dir = File.expand_path(app_name)
      return false unless File.directory?(app_dir)

      if !options[:skiprvm] && defined?(RVM) && RVM.current
        require "rvm"
        RVM.chdir(app_dir) do
          RVM.use_from_path! "."
          system("bundle", "check", out: File::NULL, err: File::NULL)
        end
      else
        Dir.chdir(app_dir) do
          system("bundle", "check", out: File::NULL, err: File::NULL)
        end
      end
    end

    def print_create_summary(app_name, log_path, started_at, ran_example)
      duration = (Time.now - started_at).round(1)
      bundle_ok = bundle_check_ok?(app_name)

      test_summary = test_summary_from_log(log_path, ran_example)

      if_ver = InlineFormsInstaller.inline_forms_version
      inst_ver = InlineFormsInstaller::VERSION

      InlineFormsInstaller::CreateLog.append_summary(
        log_path,
        started_at: started_at,
        duration_s: duration,
        inline_forms_version: if_ver,
        installer_version: inst_ver,
        bundle_ok: bundle_ok,
        test_summary: test_summary
      )

      say ""
      say "Install complete (#{duration}s)", :green
      say "  inline_forms #{if_ver} / inline_forms_installer #{inst_ver}", :green
      say "  bundle check: #{bundle_ok ? 'ok' : 'FAILED'}", bundle_ok ? :green : :red
      say "  tests: #{test_summary}", :green
      say "Install log: #{log_path}", :green
    end
    private :print_create_summary, :test_summary_from_log, :bundle_check_ok?
  end
end

Signal.trap("INT") { puts; exit }
