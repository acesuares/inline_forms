# -*- encoding : utf-8 -*-
require "inline_forms_installer/version"

module InlineFormsInstaller
  def self.gem_root
    @gem_root ||= begin
      spec = Gem.loaded_specs["inline_forms_installer"]
      spec ? spec.full_gem_path : File.expand_path("..", __dir__)
    end
  end

  def self.inline_forms_gem_root
    @inline_forms_gem_root ||= begin
      if ENV["INLINE_FORMS_ROOT"] && File.directory?(ENV["INLINE_FORMS_ROOT"])
        File.expand_path(ENV["INLINE_FORMS_ROOT"])
      else
        Gem::Specification.find_by_name("inline_forms").full_gem_path
      end
    end
  rescue Gem::MissingSpecError
    # Monorepo dev: engine sources live beside the installer gem.
    File.expand_path("..", __dir__)
  end

  def self.inline_forms_version
    @inline_forms_version ||= begin
      Gem::Specification.find_by_name("inline_forms").version.to_s
    rescue Gem::MissingSpecError
      INLINE_FORMS_VERSION
    end
  end

  # When developing unreleased 8.x gems, point env at checkouts that contain
  # built *.gem files so the installer can gem-install them into the app gemset.
  def self.discover_prerelease_env!
    if ENV["INLINE_FORMS_RELEASE_ROOT"].to_s == "" || ENV["VALIDATION_HINTS_ROOT"].to_s == ""
      dir = gem_root
      6.times do
        if ENV["INLINE_FORMS_RELEASE_ROOT"].to_s == "" &&
           File.file?(File.join(dir, "inline_forms.gemspec")) &&
           Dir[File.join(dir, "inline_forms-*.gem")].any?
          ENV["INLINE_FORMS_RELEASE_ROOT"] = dir
        end
        if ENV["VALIDATION_HINTS_ROOT"].to_s == "" &&
           File.file?(File.join(dir, "validation_hints.gemspec")) &&
           Dir[File.join(dir, "validation_hints-*.gem")].any?
          ENV["VALIDATION_HINTS_ROOT"] = dir
        end
        parent = File.expand_path("..", dir)
        break if parent == dir
        dir = parent
      end
    end

    if ENV["VALIDATION_HINTS_ROOT"].to_s == ""
      sibling_vh = File.expand_path("../validation_hints", File.expand_path("..", gem_root))
      ENV["VALIDATION_HINTS_ROOT"] = sibling_vh if File.directory?(sibling_vh)
    end

    {
      "INLINE_FORMS_RELEASE_ROOT" => "inline_forms",
      "VALIDATION_HINTS_ROOT" => "validation_hints"
    }.each do |env_key, repo_name|
      next if ENV[env_key].to_s != ""

      checkout = dev_checkout_with_gems(repo_name)
      ENV[env_key] = checkout if checkout
    end
  end

  def self.dev_checkout_with_gems(repo_name)
    [
      File.expand_path("~/code/#{repo_name}"),
      File.expand_path("~/#{repo_name}")
    ].uniq.find do |checkout|
      File.file?(File.join(checkout, "#{repo_name}.gemspec")) &&
        Dir[File.join(checkout, "#{repo_name}-*.gem")].any?
    end
  end
end

require "inline_forms_installer/creator"
