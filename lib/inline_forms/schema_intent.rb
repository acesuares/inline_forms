# -*- encoding : utf-8 -*-

module InlineForms
  # A *proposed* schema change: "add attribute X of form-element Y to model Z,
  # at this position". This is the unit the end-user-facing staging pipeline
  # (see stuff/2026-07-11-end-user-schema-changes-staging-and-pending-gate.md)
  # drafts, previews, and finally applies.
  #
  # It is a plain value object — deliberately NOT an ActiveRecord model. Where
  # intents are persisted (a drafts table) and edited (a GUI) is an app-level
  # concern; the engine only needs the structured description plus the mapping
  # to the generator that realizes it. Nothing renders from an intent at
  # runtime, so it is an audit/work-queue artifact, not config-as-data.
  #
  # STATUS is advisory metadata for a persisting app: draft -> approved ->
  # applied (or failed).
  class SchemaIntent
    STATUSES = %i[draft approved applied failed].freeze

    attr_reader :model_name, :attribute, :form_element, :values, :disabled, :after, :before
    attr_accessor :status

    def initialize(model_name:, attribute:, form_element:,
                   values: nil, disabled: nil, after: nil, before: nil, status: :draft)
      @model_name   = model_name.to_s
      @attribute    = attribute.to_sym
      @form_element = form_element.to_sym
      @values       = values
      @disabled     = disabled
      @after        = after&.to_sym
      @before       = before&.to_sym
      self.status   = status
    end

    def status=(value)
      sym = value.to_sym
      unless STATUSES.include?(sym)
        raise ArgumentError, "unknown status #{value.inspect} (expected one of #{STATUSES.inspect})"
      end

      @status = sym
    end

    # The model class this intent targets. Raises NameError if it is not
    # defined (an app should validate the name before drafting).
    def model_class
      model_name.constantize
    end

    # The `attr:form_element` token exactly as the generator expects it.
    def column_token
      "#{attribute}:#{form_element}"
    end

    # argv for `rails g inline_forms_addto <Model> <attr:form_element> [--after=..]`.
    def generator_args
      args = [ model_name, column_token ]
      args << "--after=#{after}"   if after
      args << "--before=#{before}" if before
      args
    end

    def to_h
      {
        model_name: model_name,
        attribute: attribute,
        form_element: form_element,
        values: values,
        disabled: disabled,
        after: after,
        before: before,
        status: status
      }
    end
  end
end
