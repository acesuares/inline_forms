# -*- encoding : utf-8 -*-

require "digest"

# One row per file event on a declared file slot (InlineForms::StoredFiles).
#
# Trash rows (reason removed / replaced / record_destroyed / orphaned) hold the
# bytes of a file that left its slot, so it can be restored (undo) or purged
# (bytes deleted for good, metadata kept as a tombstone = history). Event rows
# (reason uploaded) never hold bytes; they only record who put a file in a
# slot, because the slot columns are kept out of PaperTrail.
#
# States of a trash row:
#   trashed   data present, not restored, not purged, not expired
#   restored  bytes went back to the record; data NULLed, row kept as history
#   purged    data NULLed by a user or the retention sweep; tombstone kept
#   expired   purge_after passed but the sweep has not run yet: treated as
#             purged by every read path (no download, no restore)
#
# Every state change is a conditional UPDATE (WHERE still trashed) whose row
# count is checked, so a restore racing a purge, a replayed POST or a second
# click never acts twice. Lock order everywhere: the owner record's row first,
# then this table's row.
#
# Lists must never load the bytes: use +without_data+.
class InlineForms::TrashedFile < ActiveRecord::Base
  self.table_name = "inline_forms_trashed_files"

  class NotRestorable < StandardError; end
  class RecordGone < NotRestorable; end

  TRASH_REASONS = %w[removed replaced record_destroyed orphaned].freeze
  EVENT_REASONS = %w[uploaded].freeze
  REASONS = (TRASH_REASONS + EVENT_REASONS).freeze

  validates :record_type, :record_id, :attribute_name, :reason, presence: true
  validates :reason, inclusion: { in: REASONS }

  scope :without_data, -> { select(column_names - [ "data" ]) }
  scope :trash_entries, -> { where(reason: TRASH_REASONS) }
  scope :events, -> { where(reason: EVENT_REASONS) }
  scope :for_record, ->(record) { where(record_type: record.class.base_class.name, record_id: record.id) }
  scope :for_slot, ->(record, attribute) { for_record(record).where(attribute_name: attribute.to_s) }
  scope :unexpired, -> { where("purge_after IS NULL OR purge_after > ?", Time.current) }
  scope :expired, -> { where("purge_after IS NOT NULL AND purge_after <= ?", Time.current) }
  scope :still_trashed, -> { trash_entries.where(restored_at: nil, purged_at: nil) }
  scope :restorable, -> { still_trashed.unexpired }
  scope :newest_first, -> { order(trashed_at: :desc, id: :desc) }

  # ---- writing --------------------------------------------------------------

  # Moves +data+ (the bytes that just left +attribute+ on +record+) into the
  # trash. Called from inside the record's transaction.
  def self.trash!(record:, attribute:, data:, filename:, content_type:, reason:, by: nil, at: Time.current)
    retention = InlineForms.file_trash_retention
    create!(
      record_type: record.class.base_class.name,
      record_id: record.id,
      attribute_name: attribute.to_s,
      filename: filename,
      content_type: content_type,
      byte_size: data&.bytesize,
      checksum: data && Digest::SHA256.hexdigest(data),
      data: data,
      reason: reason.to_s,
      trashed_by_id: by,
      trashed_at: at,
      purge_after: retention && at + retention
    )
  end

  # Metadata-only "a file was put in this slot" event.
  def self.record_upload!(record:, attribute:, filename:, content_type:, byte_size:, checksum:, by: nil, at: Time.current)
    create!(
      record_type: record.class.base_class.name,
      record_id: record.id,
      attribute_name: attribute.to_s,
      filename: filename,
      content_type: content_type,
      byte_size: byte_size,
      checksum: checksum,
      reason: "uploaded",
      trashed_by_id: by,
      trashed_at: at
    )
  end

  # Purges every trash row whose retention has passed. Returns the number
  # purged. Idempotent; safe to run while users work.
  def self.purge_expired!
    ids = still_trashed.expired.pluck(:id)
    ids.count { |id| find_by(id: id)&.purge!(by: nil) }
  end

  # ---- state ----------------------------------------------------------------

  def trash_entry?
    TRASH_REASONS.include?(reason)
  end

  def event?
    EVENT_REASONS.include?(reason)
  end

  def restored?
    restored_at.present?
  end

  def purged?
    purged_at.present?
  end

  def expired?
    purge_after.present? && purge_after <= Time.current
  end

  # Still holds bytes that may be downloaded, restored or purged.
  def trashed?
    trash_entry? && !restored? && !purged? && !expired?
  end

  # :trashed, :restored, :purged, :expired or :event
  def state
    return :event if event?
    return :restored if restored?
    return :purged if purged?
    return :expired if expired?

    :trashed
  end

  # The record this file belongs to, or nil when it was destroyed (or its
  # class is gone). Never constantizes anything but a stored record_type.
  #
  # Loaded without the slots' byte columns (it is used for authorization and
  # labels; reading a file goes through the slot API, which queries fresh).
  def owner
    klass = owner_class
    return nil unless klass

    scope = klass.unscoped
    if klass.respond_to?(:inline_forms_file_slots)
      blob_columns = klass.inline_forms_file_slots.values.map { |slot| slot[:data] }
      scope = scope.select(klass.column_names - blob_columns)
    end
    scope.find_by(klass.primary_key => record_id)
  end

  def owner_class
    klass = record_type.safe_constantize
    klass.is_a?(Class) && klass < ActiveRecord::Base ? klass : nil
  end

  # The bytes, loaded on demand (lists select without them).
  def file_data
    self.class.where(id: id).pick(:data)
  end

  # ---- actions --------------------------------------------------------------

  # Permanently deletes the bytes. Returns true when this call purged the row,
  # false when it was already restored or purged (stale page, replayed POST).
  def purge!(by:)
    changes = { data: nil, purged_at: Time.current, purged_by_id: by, updated_at: Time.current }
    if InlineForms.file_trash_redact_on_purge
      changes[:filename] = nil
      changes[:redacted] = true
    end
    count = self.class.where(id: id).still_trashed.update_all(changes)
    reload if count == 1
    count == 1
  end

  # Puts the bytes back into the slot. If the slot holds a file now (someone
  # uploaded since), that file goes to the trash first (reason replaced) —
  # never a silent overwrite. Raises RecordGone when the record was destroyed
  # (restore the record instead; its files come back with it) and
  # NotRestorable when the entry is no longer trashed.
  def restore!(by:)
    record_class = owner_class
    raise RecordGone, "the record was deleted" unless record_class

    record_class.transaction do
      record = record_class.unscoped.lock.find_by(record_class.primary_key => record_id)
      raise RecordGone, "the record was deleted" unless record

      payload = self.class.lock.where(id: id).restorable.pick(:data, :filename, :content_type)
      raise NotRestorable, "this file can no longer be restored" unless payload

      now = Time.current
      count = self.class.where(id: id).restorable.update_all(data: nil, restored_at: now, restored_by_id: by, updated_at: now)
      raise NotRestorable, "this file can no longer be restored" unless count == 1

      data, filename, content_type = payload
      record.inline_forms_put_file!(attribute_name, data: data, filename: filename, content_type: content_type, by: by)
      reload
      record
    end
  end
end
