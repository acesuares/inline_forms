# -*- encoding: utf-8 -*-
require "fileutils"
require "shellwords"

module InlineFormsInstaller
  module CreateLog
    module_function

    def basename_for(started_at = Time.now)
      "inline_forms_create-#{started_at.strftime('%Y%m%d-%H%M%S')}.log"
    end

    def final_path(app_name, started_at = Time.now)
      File.expand_path(File.join(app_name, "log", basename_for(started_at)))
    end

    def write_header(path, started_at: Time.now, display_path: nil)
      FileUtils.mkdir_p(File.dirname(path))
      shown = display_path || path
      File.open(path, "w") do |f|
        f.puts "=== inline_forms create install log ==="
        f.puts "started: #{started_at.iso8601}"
        f.puts "Install log: #{shown}"
        f.puts ""
      end
    end

    def append_summary(path, started_at:, duration_s:, inline_forms_version:, installer_version:, bundle_ok:, test_summary:)
      append_section(
        path,
        "install summary",
        <<~TEXT
          finished: #{Time.now.iso8601}
          duration: #{duration_s}s
          inline_forms: #{inline_forms_version}
          inline_forms_installer: #{installer_version}
          bundle check: #{bundle_ok ? "ok" : "FAILED"}
          tests: #{test_summary}
          Install log: #{path}
        TEXT
      )
    end

    def tee_rails_new(app_name, shell_command, started_at: Time.now)
      final = final_path(app_name, started_at)
      tmp = File.expand_path(basename_for(started_at))
      ENV["INLINE_FORMS_INSTALLER_LOG"] = tmp
      ENV["INLINE_FORMS_INSTALLER_LOG_DISPLAY"] = final
      ENV["INLINE_FORMS_CREATE_STARTED_AT"] = started_at.iso8601

      write_header(tmp, started_at: started_at, display_path: final)

      ok = system(
        "bash", "-c",
        "#{shell_command} 2>&1 | tee -a #{Shellwords.escape(tmp)}; exit ${PIPESTATUS[0]}"
      )

      if ok && File.directory?(app_name)
        FileUtils.mkdir_p(File.join(app_name, "log"))
        FileUtils.mv(tmp, final) if File.exist?(tmp)
      elsif File.exist?(tmp)
        FileUtils.mkdir_p(File.dirname(final))
        FileUtils.mv(tmp, final)
      end

      [ok, final]
    end

    def append_section(path, title, body)
      return if path.to_s.strip.empty?

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.puts "\n=== #{title} ===\n#{body}" }
    end
  end
end
