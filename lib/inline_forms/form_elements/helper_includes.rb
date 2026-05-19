# frozen_string_literal: true

module InlineForms
  module FormElements
    # Mixes every form-element helper module into InlineFormsHelper so views
    # keep calling `text_field_show`, etc. (see name_list.html.erb).
    module HelperIncludes
      extend ActiveSupport::Concern

      included do
        InlineForms::FormElements.helper_modules.each { |mod| include mod }
      end
    end
  end
end
