# frozen_string_literal: true

require_relative "test_helper"
require "inline_forms/gem_files"

# 8.1.75 still packaged test/, .forgejo/ and the RuboCop and Ruby version files.
class GemFilesTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)

  def test_only_what_an_installed_gem_needs
    top_level = InlineFormsGemFiles.gem_files(include_installer: false).map { |file| file.split("/").first }.uniq.sort

    assert_equal(%w[CHANGELOG.md LICENSE.txt README.rdoc app archived inline_forms.gemspec lib vendor], top_level)
  end

  def test_the_installer_has_its_own_files
    files = InlineFormsGemFiles.gem_files(include_installer: true)

    assert_equal(%w[bin inline_forms_installer.gemspec lib], files.map { |file| file.split("/").first }.uniq.sort)
    assert_includes(files, "bin/inline_forms")
    assert_includes(files, "lib/inline_forms_installer/creator.rb")
    assert(files.any? { |file| file.start_with?("lib/installer_templates/") })
  end

  def test_an_untracked_file_stays_out
    path = File.join(REPO_ROOT, "gem_files_probe_#{Process.pid}.txt")
    File.write(path, "probe")

    refute_includes(InlineFormsGemFiles.gem_files(include_installer: false), File.basename(path))
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
