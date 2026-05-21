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

    def tee_rails_new(app_name, shell_command, started_at: Time.now)
      final = final_path(app_name, started_at)
      tmp = File.expand_path(basename_for(started_at))
      ENV["INLINE_FORMS_INSTALLER_LOG"] = final
      ENV["INLINE_FORMS_CREATE_STARTED_AT"] = started_at.iso8601

      ok = system(
        "bash", "-c",
        "#{shell_command} 2>&1 | tee #{Shellwords.escape(tmp)}; exit ${PIPESTATUS[0]}"
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
