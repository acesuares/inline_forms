# -*- encoding : utf-8 -*-

module InlineForms
  # Dev-only GUI to add a field to a model through the browser, building on the
  # schema-staging services. Two kinds of addition:
  #
  #  * a scalar field (text_field, integer_field, date_select, ...): apply runs
  #    inline_forms_addto in-process (model edit + migration file) but NOT
  #    db:migrate; the pending-migration gate covers the window.
  #  * a :header (section separator): no column, so no migration at all — it
  #    appears on the next reload with no db:migrate needed.
  #
  # Optionally writes a human label into config/locales/inline_forms_labels.
  # <locale>.yml (via SchemaLabel) so the field/header renders friendly text.
  #
  # Authoring is confined to non-production (the sync guarantee: only a dev
  # checkout authors; generated files land in the working tree and follow the
  # normal commit -> deploy path). Mounted only in the example app + test dummy.
  class SchemaController < InlineFormsApplicationController
    # A section header: not a real column-backed field.
    HEADER = "header"

    layout "inline_forms_schema"

    before_action :require_non_production
    before_action :load_form_options

    # Injectable so tests record instead of mutating the working tree.
    cattr_accessor :generator_executor
    cattr_accessor :label_writer

    def new
      @intent_params = blank_intent_params
    end

    def preview
      @intent_params = intent_params
      @error = validate_intent(@intent_params)
      return render(:new) if @error

      @intent    = build_intent(@intent_params)
      @is_header = @intent.form_element == :header
      if @is_header
        @attribute_list = InlineForms::SchemaPreview.attribute_list_for(@intent.model_class, @intent)
      else
        @preview, @attribute_list = InlineForms::SchemaPreview.build(@intent)
      end
    end

    def create
      @intent_params = intent_params
      @error = validate_intent(@intent_params)
      return render(:new) if @error

      @intent    = build_intent(@intent_params)
      @is_header = @intent.form_element == :header
      begin
        @migration_path = InlineForms::SchemaApply.new(@intent).generate!(
          destination_root: Rails.root,
          executor: generator_executor || InlineForms::SchemaApply::DEFAULT_GENERATE_EXECUTOR
        )
        @migration_basename = @migration_path && File.basename(@migration_path)
        write_label!
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
      @locales       = I18n.available_locales.map(&:to_s)
      @default_locale = I18n.default_locale.to_s
    end

    def blank_intent_params
      { model_name: "", attribute: "", form_element: @form_elements.first.to_s,
        after: "", label: "", locale: @default_locale }
    end

    def intent_params
      {
        model_name:   params[:model_name].to_s.strip,
        attribute:    params[:attribute].to_s.strip,
        form_element: params[:form_element].to_s.strip,
        after:        params[:after].to_s.strip,
        label:        params[:label].to_s.strip,
        locale:       params[:locale].to_s.strip.presence || @default_locale
      }
    end

    def build_intent(p)
      InlineForms::SchemaIntent.new(
        model_name:   p[:model_name],
        attribute:    p[:attribute],
        form_element: p[:form_element],
        after:        p[:after].presence
      )
    end

    def write_label!
      return if @intent_params[:label].blank?

      writer = label_writer || InlineForms::SchemaLabel.method(:write)
      @label_path = writer.call(
        destination_root: Rails.root,
        model_class: @intent.model_class,
        attribute: @intent.attribute,
        label: @intent_params[:label],
        locale: @intent_params[:locale]
      )
      @label_basename = @label_path && File.basename(@label_path.to_s)
    end

    # Returns an error string, or nil when the params are usable.
    def validate_intent(p)
      return "Choose a model." if p[:model_name].blank?
      return "Enter an attribute name." if p[:attribute].blank?
      unless p[:attribute].match?(/\A[a-z_][a-z0-9_]*\z/)
        return "Attribute name must be lowercase letters, digits and underscores (e.g. internal_note)."
      end

      allowed = @form_elements.map(&:to_s) + [ HEADER ]
      return "Unsupported form element #{p[:form_element].inspect}." unless allowed.include?(p[:form_element])

      klass = safe_model_class(p[:model_name])
      return "Unknown model #{p[:model_name].inspect}." unless klass
      unless model_usable?(klass)
        return "#{p[:model_name]} is not an inline_forms model (no inline_forms_attribute_list)."
      end
      # A header has no column, so the column-collision check does not apply.
      if p[:form_element] != HEADER && klass.column_names.include?(p[:attribute])
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
