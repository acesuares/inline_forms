# -*- encoding: utf-8 -*-

module InlineFormsGemFiles
  INSTALLER_FILE_PREFIXES = %w[
    bin/inline_forms
    lib/inline_forms_installer.rb
    lib/inline_forms_installer/
    lib/installer_templates/
    inline_forms_installer.gemspec
  ].freeze

  # The schema-GUI gem lives in its own subdirectory with its own gemspec
  # (inline_forms_schema_edit/inline_forms_schema_edit.gemspec) and packages
  # its files itself; exclude the whole subtree from BOTH gems here.
  SCHEMA_GUI_FILE_PREFIXES = %w[
    inline_forms_schema_edit/
  ].freeze

  # Scratch / local-notes dir. It holds working notes and, crucially, secrets
  # such as stuff/forgejo-token (mode 0600, only used by CI pushes to forgejo).
  # It must NEVER be packaged into a gem. Do not rely on git ignore for this:
  # gem_files sweeps untracked files too, and the global excludes file that
  # ignores stuff/ is per-machine (present here, absent on the release box), so
  # the token leaked into `gem build` on the release machine. Exclude it hard,
  # independent of any ignore configuration.
  EXCLUDED_FILE_PREFIXES = %w[
    stuff/
  ].freeze

  module_function

  REPO_ROOT = File.expand_path("../..", __dir__)

  def gem_files(include_installer:)
    files =
      if File.directory?(File.join(REPO_ROOT, ".git"))
        Dir.chdir(REPO_ROOT) do
          tracked = `git ls-files`.split("\n")
          untracked = `git ls-files --others --exclude-standard`.split("\n")
          (tracked + untracked).uniq
        end
      else
        Dir.chdir(REPO_ROOT) do
          Dir.glob("**/*", File::FNM_DOTMATCH).reject do |f|
            f.start_with?(".git/", ".bundle/", "pkg/") ||
              f == ".git" || f == ".bundle"
          end
        end
      end

    files.select! { |f| File.file?(File.join(REPO_ROOT, f)) }

    files.reject! do |f|
      EXCLUDED_FILE_PREFIXES.any? { |prefix| f == prefix || f.start_with?(prefix) }
    end

    files.reject! do |f|
      SCHEMA_GUI_FILE_PREFIXES.any? { |prefix| f == prefix || f.start_with?(prefix) }
    end

    files.reject do |f|
      installer_file = INSTALLER_FILE_PREFIXES.any? { |prefix| f == prefix || f.start_with?(prefix) }
      include_installer ? !installer_file : installer_file
    end
  end
end
