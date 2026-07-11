# frozen_string_literal: true

# Models the `inline_forms_addto` pre-migrate window: the attribute_list has a
# row (`:pending_note`) whose column does NOT exist on the gizmos table yet, so
# it exercises InlineForms.attribute_pending_migration? end to end. `:name` and
# `:created_at` are real columns; `:section` is a header. See
# test/integration/pending_migration_gate_test.rb.
class Gizmo < ApplicationRecord
  validates :name, presence: true

  scope :inline_forms_list, -> { order(:name, :id) }

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ],
      [ :section, :header ],
      [ :pending_note, :text_field ],
      [ :created_at, :info ]
    ]
  end
end
