# frozen_string_literal: true

require "inline_forms/form_elements/helper_includes"

module InlineForms
  module FormElements
    module_function

    def load_helpers!
      return if @helpers_loaded

      helpers_root = InlineForms::Engine.root.join("lib/inline_forms/form_elements")
      Dir[helpers_root.join("*_helper.rb")].sort.each { |path| require path.to_s }
      @helpers_loaded = true
    end

    def helper_modules
      load_helpers!
      Dir[InlineForms::Engine.root.join("lib/inline_forms/form_elements/*_helper.rb")]
        .sort
        .filter_map do |path|
          const_name = File.basename(path, ".rb").camelize
          const_get(const_name) if const_defined?(const_name, false)
        end
    end
  end
end
