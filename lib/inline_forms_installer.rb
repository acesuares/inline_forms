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
end

require "inline_forms_installer/creator"
