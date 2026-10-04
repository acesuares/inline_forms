# -*- encoding: utf-8 -*-

require "delegate"
require "rubygems/package"

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
  #
  # Same for Claude Code files: .claude/ (untracked, per checkout:
  # launch.json, settings.local.json, worktrees) and CLAUDE.md (committed so
  # worktrees see it, but repo instructions, not gem content).
  EXCLUDED_FILE_PREFIXES = %w[
    stuff/
    .claude/
    CLAUDE.md
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

  # Mode a file gets inside the .gem: 0755 if the owner may execute it,
  # else 0644. RubyGems packages each file's on-disk mode (File.lstat) and
  # `gem install` restores it, and this checkout is group-only (rw-rw----),
  # so 8.1.53 shipped every file as 0660: only the installing user and group
  # could read the installed gem, `require "inline_forms"` failed silently
  # for anyone else (Bundler swallows the LoadError), and a Docker image that
  # installs as root and runs as another user could not boot.
  def packaged_mode(mode)
    (mode & 0o100).zero? ? 0o644 : 0o755
  end

  # Wraps the tar writer Gem::Package#add_files writes to, so every file
  # goes in with packaged_mode instead of its on-disk mode.
  class ReadableTar < SimpleDelegator
    def add_file_simple(name, mode, size, &block)
      __getobj__.add_file_simple(name, InlineFormsGemFiles.packaged_mode(mode), size, &block)
    end
  end

  module ReadablePackage
    def add_files(tar)
      super(ReadableTar.new(tar))
    end
  end
end

# Loaded by every gemspec in this repo, so `gem build`, `rake build` and the
# CI full gate all package world-readable files whatever the checkout's modes.
Gem::Package.prepend(InlineFormsGemFiles::ReadablePackage) unless Gem::Package <= InlineFormsGemFiles::ReadablePackage
