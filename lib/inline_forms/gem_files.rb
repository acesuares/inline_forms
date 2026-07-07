# -*- encoding: utf-8 -*-

module InlineFormsGemFiles
  INSTALLER_FILE_PREFIXES = %w[
    bin/inline_forms
    lib/inline_forms_installer.rb
    lib/inline_forms_installer/
    lib/installer_templates/
    inline_forms_installer.gemspec
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

    files.reject do |f|
      installer_file = INSTALLER_FILE_PREFIXES.any? { |prefix| f == prefix || f.start_with?(prefix) }
      include_installer ? !installer_file : installer_file
    end
  end
end
