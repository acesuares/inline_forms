# -*- encoding : utf-8 -*-

module InlineFormsSchemaEdit
  # Validation shared by the GUI (SchemaController) and the import/replay
  # side (BatchImport / rake schema_edit:apply_batch). Validates a plain
  # params-shaped hash against the CURRENT app's models — deliberately
  # re-run at import time, because the checkout that replays a batch may be
  # newer than the tenant that drafted it.
  #
  # ADDITIVE-ONLY GUARANTEE: only scalar form elements from
  # SchemaPreview.supported_form_elements plus :header are accepted; those
  # map to `add_column` (nullable) or no column at all. Nothing destructive
  # or relational can enter a batch through this gate.
  module IntentValidator
    HEADER = "header"

    ATTRIBUTE_FORMAT = /\A[a-z_][a-z0-9_]*\z/

    module_function

    # Returns an error string, or nil when the intent is usable.
    # `p` keys (string or symbol): model_name, attribute, form_element.
    def error_for(p)
      p = p.symbolize_keys
      return "Choose a model." if p[:model_name].blank?
      return "Enter an attribute name." if p[:attribute].blank?
      unless p[:attribute].to_s.match?(ATTRIBUTE_FORMAT)
        return "Attribute name must be lowercase letters, digits and underscores (e.g. internal_note)."
      end

      allowed = InlineForms::SchemaPreview.supported_form_elements.map(&:to_s) + [ HEADER ]
      unless allowed.include?(p[:form_element].to_s)
        return "Unsupported form element #{p[:form_element].inspect}."
      end

      klass = safe_model_class(p[:model_name].to_s)
      return "Unknown model #{p[:model_name].inspect}." unless klass
      unless model_usable?(klass)
        return "#{p[:model_name]} is not an inline_forms model (no inline_forms_attribute_list)."
      end
      # A header has no column, so the column-collision check does not apply.
      if p[:form_element].to_s != HEADER && klass.column_names.include?(p[:attribute].to_s)
        return "#{p[:model_name]} already has a #{p[:attribute]} column."
      end

      nil
    end

    def safe_model_class(name)
      klass = name.safe_constantize
      klass if klass.is_a?(Class) && klass < ActiveRecord::Base
    rescue StandardError
      nil
    end

    def model_usable?(klass)
      !klass.abstract_class? &&
        klass.instance_methods.include?(:inline_forms_attribute_list) &&
        klass.respond_to?(:column_names)
    rescue StandardError
      false
    end

    def candidate_models
      ActiveRecord::Base.descendants.select { |k| model_usable?(k) && k.name.present? }
                        .map(&:name).uniq.sort
    rescue StandardError
      []
    end
  end
end
