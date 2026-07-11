# -*- encoding : utf-8 -*-

module InlineForms
  # A batch of proposed schema changes (SchemaIntentRecord rows), the unit
  # the automated pipeline processes. Lifecycle:
  #
  #   draft      — admin is still adding/removing intents (the "cart")
  #   submitted  — frozen; waiting for CI to pick it up
  #   processing — CI is generating code / running the test gate
  #   ready      — code committed (git_sha set); waiting for the deploy window
  #   applied    — migrated + restarted
  #   failed     — any step failed; error holds the diagnostics
  #
  # IMMUTABILITY: the moment a batch leaves draft, its intents are frozen
  # (enforced in SchemaIntentRecord) and the batch itself only accepts
  # status-flow updates (status, git_sha, error, applied_at). content_digest
  # seals the intent list at submit time; export re-emits it and the import
  # side re-verifies it, so a batch provably cannot change between "admin
  # pressed submit" and "CI replayed it".
  class SchemaBatch < ActiveRecord::Base
    self.table_name = "inline_forms_schema_batches"

    STATUSES = %w[draft submitted processing ready applied failed].freeze
    TRANSITIONS = {
      "draft"      => %w[submitted],
      "submitted"  => %w[processing failed],
      "processing" => %w[ready failed],
      "ready"      => %w[applied failed],
      "failed"     => %w[submitted],   # resubmit after a fix
      "applied"    => []
    }.freeze

    # Columns the pipeline may still write after the batch left draft.
    STATUS_FLOW_COLUMNS = %w[status git_sha error applied_at updated_at].freeze

    has_many :intents,
             -> { order(:position, :id) },
             class_name: "InlineForms::SchemaIntentRecord",
             foreign_key: :batch_id,
             inverse_of: :batch,
             dependent: :destroy

    validates :status, inclusion: { in: STATUSES }

    before_update :allow_only_status_flow_after_draft
    before_destroy :only_draft_batches_are_destroyable

    scope :with_status, ->(s) { where(status: s.to_s) }

    def self.current_draft
      with_status(:draft).order(:id).first_or_create!
    end

    def draft? = status == "draft"
    def submitted? = status == "submitted"
    def processing? = status == "processing"
    def ready? = status == "ready"
    def applied? = status == "applied"
    def failed? = status == "failed"

    # ready + the requested window (if any) has arrived.
    def due_for_apply?
      ready? && (window_at.nil? || window_at <= Time.current)
    end

    # Freeze the batch: seal the digest, record who/when, optionally a window.
    def submit!(requested_by: nil, window_at: nil)
      raise ArgumentError, "only a draft batch can be submitted" unless draft?
      raise ArgumentError, "cannot submit an empty batch" if intents.reload.empty?

      with_lock do
        self.status         = "submitted"
        self.submitted_at   = Time.current
        self.window_at      = window_at
        self.requested_by   = requested_by if requested_by
        self.content_digest = InlineFormsSchemaGui::BatchExport.digest_for(self)
        save!
      end
      self
    end

    # Status-flow update used by the pipeline (CI callback / apply task).
    def transition!(to, git_sha: nil, error: nil)
      to = to.to_s
      unless TRANSITIONS.fetch(status, []).include?(to)
        raise ArgumentError, "illegal transition #{status} -> #{to}"
      end

      self.status  = to
      self.git_sha = git_sha if git_sha
      self.error   = error if error
      self.applied_at = Time.current if to == "applied"
      save!
      self
    end

    private

    def allow_only_status_flow_after_draft
      return if status_was == "draft"

      illegal = changed - STATUS_FLOW_COLUMNS
      return if illegal.empty?

      errors.add(:base, "batch is frozen after submit (illegal change to #{illegal.join(', ')})")
      throw :abort
    end

    def only_draft_batches_are_destroyable
      return if draft?

      errors.add(:base, "only draft batches can be deleted")
      throw :abort
    end
  end
end
