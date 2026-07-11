# -*- encoding : utf-8 -*-

module InlineForms
  # Dev-only GUI to add a scalar attribute to a model: pick model / name / form
  # element / placement, preview the field with NO migration (virtual attribute
  # on a throwaway subclass), then apply by running the inline_forms_addto
  # generator in-process (model edit + migration file) WITHOUT running
  # db:migrate. The pending-migration gate renders the new field as a
  # placeholder until the developer migrates + restarts.
  #
  # Authoring is confined to non-production (the sync guarantee: only a dev
  # checkout authors, the generated files land in the working tree, and the
  # developer commits + deploys — production is never edited in place). This
  # controller is mounted only in the example app and the test dummy; real
  # generated apps ship the code but no route to it.
  class SchemaController < InlineFormsApplicationController
    # Self-contained layout: the full inline_forms chrome needs current_user /
    # devise / tabs, which a dev utility should not depend on.
    layout "inline_forms_schema"

    before_action :require_non_production
    before_action :load_form_options

    # Injectable so tests record the generator args instead of mutating the
    # working tree. nil -> real in-process generation (SchemaApply default).
    cattr_accessor :generator_executor

    def new
      @intent_params = blank_intent_params
    end

    def preview
      @intent_params = intent_params
      @error = validate_intent(@intent_params)
      return render(:new) if @error

      # form_element is validated to the supported scalar set, so build is safe.
      @intent = build_intent(@intent_params)
      @preview, @attribute_list = InlineForms::SchemaPreview.build(@intent)
    end

    def create
      @intent_params = intent_params
      @error = validate_intent(@intent_params)
      return render(:new) if @error

      @intent = build_intent(@intent_params)
      apply   = InlineForms::SchemaApply.new(@intent)
      begin
        @migration_path = apply.generate!(
          destination_root: Rails.root,
          executor: generator_executor || InlineForms::SchemaApply::DEFAULT_GENERATE_EXECUTOR
        )
        @migration_basename = @migration_path && File.basename(@migration_path)
      rescue StandardError => e
        @error = "Generator failed: #{e.message}"
        render(:new)
      end
    end

    private

    def require_non_production
      head :not_found if Rails.env.production?
    end

    def load_form_options
      @form_elements = InlineForms::SchemaPreview.supported_form_elements
      @models        = candidate_models
    end

    def blank_intent_params
      { model_name: "", attribute: "", form_element: @form_elements.first.to_s, after: "" }
    end

    def intent_params
      {
        model_name:   params[:model_name].to_s.strip,
        attribute:    params[:attribute].to_s.strip,
        form_element: params[:form_element].to_s.strip,
        after:        params[:after].to_s.strip
      }
    end

    def build_intent(p)
      InlineForms::SchemaIntent.new(
        model_name:   p[:model_name],
        attribute:    p[:attribute],
        form_element: p[:form_element],
        after:        (p[:after].presence)
      )
    end

    # Returns an error string, or nil when the params are usable.
    def validate_intent(p)
      return "Choose a model." if p[:model_name].blank?
      return "Enter an attribute name." if p[:attribute].blank?
      unless p[:attribute].match?(/\A[a-z_][a-z0-9_]*\z/)
        return "Attribute name must be lowercase letters, digits and underscores (e.g. internal_note)."
      end
      unless @form_elements.map(&:to_s).include?(p[:form_element])
        return "Unsupported form element #{p[:form_element].inspect}."
      end

      klass = safe_model_class(p[:model_name])
      return "Unknown model #{p[:model_name].inspect}." unless klass
      unless model_usable?(klass)
        return "#{p[:model_name]} is not an inline_forms model (no inline_forms_attribute_list)."
      end
      if klass.column_names.include?(p[:attribute])
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

    # Best-effort list for the model datalist. Uses already-loaded AR
    # descendants (populated in tests + once an app has touched its models);
    # the model field is a text input, so an incomplete list never blocks use.
    def candidate_models
      ActiveRecord::Base.descendants.select { |k| model_usable?(k) && k.name.present? }
                        .map(&:name).uniq.sort
    rescue StandardError
      []
    end
  end
end
