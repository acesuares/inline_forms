# -*- encoding : utf-8 -*-

module InlineForms
  # A persisted schema intent: one proposed "add attribute X of form-element
  # Y to model Z at this position" row inside a SchemaBatch. This is the AR
  # counterpart of the InlineForms::SchemaIntent value object (which stays a
  # plain object in inline_forms); #to_schema_intent bridges the two.
  #
  # Rows are editable only while their batch is a draft. `migration_version`
  # is the one exception: the pipeline backfills it after apply.
  class SchemaIntentRecord < ActiveRecord::Base
    self.table_name = "inline_forms_schema_intents"

    # Pipeline backfill columns, writable after the batch froze.
    BACKFILL_COLUMNS = %w[migration_version updated_at].freeze

    belongs_to :batch,
               class_name: "InlineForms::SchemaBatch",
               foreign_key: :batch_id,
               inverse_of: :intents

    # Columns are `target_model` / `attr_name` (`model_name` collides with
    # ActiveModel::Naming, `attribute` with the AR attribute API); the export
    # JSON keys stay "model_name"/"attribute" to match the SchemaIntent
    # value object.
    validates :target_model, :attr_name, :form_element, presence: true

    before_save :only_in_draft_batches
    before_destroy :only_in_draft_batches_destroy

    before_create :assign_position

    def to_schema_intent
      InlineForms::SchemaIntent.new(
        model_name:   target_model,
        attribute:    attr_name,
        form_element: form_element,
        after:        after_attr.presence,
        before:       before_attr.presence
      )
    end

    def header? = form_element == "header"

    # Canonical export shape; also the digest input (see BatchExport), so
    # key order is fixed and values are normalized strings/nil.
    def as_export
      {
        "model_name"   => target_model,
        "attribute"    => attr_name,
        "form_element" => form_element,
        "after"        => after_attr.presence,
        "before"       => before_attr.presence,
        "label"        => label.presence,
        "locale"       => locale.presence
      }
    end

    private

    def assign_position
      self.position ||= (batch&.intents&.maximum(:position) || 0) + 1
    end

    def only_in_draft_batches
      return if batch.nil? || batch.draft?
      return if !new_record? && (changed - BACKFILL_COLUMNS).empty?

      errors.add(:base, "batch is frozen; intents can no longer change")
      throw :abort
    end

    def only_in_draft_batches_destroy
      return if batch.nil? || batch.draft?

      errors.add(:base, "batch is frozen; intents can no longer be removed")
      throw :abort
    end
  end
end
