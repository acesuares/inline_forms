# -*- encoding : utf-8 -*-

require "digest"

# Declared file slots for :simple_file_field: raw bytes in the record's own
# table (a binary/LONGBLOB column), with a content-type and a filename column.
# Replaces the hand-written `<attr>=` setters hosts used to write per model.
#
#   class Client < ApplicationRecord
#     include InlineForms::StoredFiles
#     inline_forms_file :filename                    # data / content_type
#     inline_forms_file :begeleidingsplan_filename   # begeleidingsplan_data / _content_type
#     inline_forms_file :manual, data: :manual_bytes # explicit column names
#   end
#
# Column names default from the attribute: `filename` -> `data` and
# `content_type`; `<base>_filename` and any other `<base>` -> `<base>_data` and
# `<base>_content_type`.
#
# What a declared slot gets:
# * a setter that accepts an uploaded file (ignores nil, like the hand-written
#   ones; a String is a plain filename write for seeds/console code). The
#   setter lives in a prepended module, so it wins over a `def <attr>=` in the
#   class body regardless of order -- and such a def raises outside
#   production, because it would be dead code that looks live.
# * replace = the old bytes go to the trash (InlineForms::TrashedFile) in the
#   same transaction as the save; remove/restore/purge never lose bytes except
#   through an explicit purge or the retention sweep.
# * the three slot columns are added to PaperTrail's `skip:` (whichever order
#   `has_paper_trail` and `inline_forms_file` run in): file history lives in
#   the trash table, never in `versions`, so a revert never touches a file.
# * destroying the record trashes its files first (reason record_destroyed);
#   reverting that destroy brings them back.
#
# Requires the `inline_forms_trashed_files` table (`rails g
# inline_forms:file_trash`). Models without `inline_forms_file` are untouched.
module InlineForms::StoredFiles
  extend ActiveSupport::Concern

  class HandWrittenSetterError < StandardError; end

  # Strips any client path (IE sends C:\...\x.pdf) and replaces everything
  # but word characters, dots and dashes -- the rule StProject's hand-written
  # setters used, so existing filenames keep their shape.
  def self.sanitize_filename(name)
    name.to_s.split(/[\\\/]/).last.to_s.gsub(/[^\w.\-]/, "_")
  end

  # Revert support (InlineFormsController#revert), called before the reified
  # record is saved, inside the revert's transaction. Returns the trash
  # entries to mark restored after the save (finish_revert!).
  #
  # * revert of an update (record persisted): put the slot columns back to
  #   their DB values -- a pre-adoption version row may still carry an old
  #   filename, and must not land on the current bytes.
  # * undo of a destroy (row gone): copy each slot's newest restorable
  #   record_destroyed entry onto the record BEFORE the save, so presence
  #   validations on the filename pass; a slot whose file was purged in the
  #   meantime comes back empty (never a name without bytes). An entry whose
  #   bytes fail their SHA-256 check raises NotRestorable (nothing restored).
  # * row exists already (replayed undo): nothing; persist_reverted_primary!
  #   leaves the slot columns alone.
  def self.prepare_revert!(record)
    klass = record.class
    return [] unless klass.respond_to?(:inline_forms_file_slots) && klass.inline_forms_file_slots.any?

    if record.persisted?
      record.restore_attributes(klass.inline_forms_file_columns)
      return []
    end
    return [] if record.id.nil? || klass.unscoped.exists?(klass.primary_key => record.id)

    klass.inline_forms_file_slots.filter_map do |attribute, slot|
      entry = InlineForms::TrashedFile.lock.for_slot(record, attribute)
                .where(reason: "record_destroyed").restorable.newest_first.first
      if entry
        # Same integrity check as TrashedFile#restore!: a mismatch raises
        # NotRestorable and the whole revert rolls back.
        InlineForms::TrashedFile.verify_checksum!(id: entry.id, data: entry.data, checksum: entry.checksum)
        record.send(:write_attribute, slot[:data], entry.data)
        record.send(:write_attribute, attribute.to_s, entry.filename)
        record.send(:write_attribute, slot[:content_type], entry.content_type)
      else
        [ slot[:data], attribute.to_s, slot[:content_type] ].each { |column| record.send(:write_attribute, column, nil) }
      end
      entry
    end
  end

  # Marks the entries prepare_revert! put back as restored. Raises (rolling
  # the revert back) if one was purged or restored concurrently.
  def self.finish_revert!(entries, by: nil)
    entries.each do |entry|
      now = Time.current
      count = InlineForms::TrashedFile.where(id: entry.id).restorable
                .update_all(data: nil, restored_at: now, restored_by_id: by, updated_at: now)
      raise InlineForms::TrashedFile::NotRestorable, "file #{entry.id} changed during revert" unless count == 1
    end
  end

  # Re-merges the slot columns into PaperTrail's skip list when
  # `has_paper_trail` runs after `inline_forms_file` (it replaces the options).
  module PaperTrailSkipHook
    def has_paper_trail(*args, **kwargs, &block)
      result = super
      inline_forms_merge_paper_trail_skip!
      result
    end
  end

  included do
    class_attribute :inline_forms_file_slots, instance_writer: false, default: {}.freeze

    validate :inline_forms_validate_staged_files
    before_save :inline_forms_trash_replaced_files
    after_save :inline_forms_record_uploaded_files
    before_destroy :inline_forms_trash_files_on_destroy, prepend: true

    singleton_class.prepend(PaperTrailSkipHook)
  end

  class_methods do
    def inline_forms_file(attribute, data: nil, content_type: nil)
      attribute = attribute.to_sym
      defaults = InlineForms.file_slot_columns(attribute)
      data ||= defaults[:data]
      content_type ||= defaults[:content_type]
      slot = { data: data.to_s, content_type: content_type.to_s }.freeze
      self.inline_forms_file_slots = inline_forms_file_slots.merge(attribute => slot).freeze

      inline_forms_file_setters.define_method("#{attribute}=") do |value|
        inline_forms_assign_file(attribute, value) { super(value) }
      end

      inline_forms_hand_written_setter!(attribute) if method_defined?(:"#{attribute}=", false)
      inline_forms_merge_paper_trail_skip!
      attribute
    end

    def inline_forms_file_slot?(attribute)
      inline_forms_file_slots.key?(attribute.to_s.to_sym)
    end

    def inline_forms_file_slot(attribute)
      inline_forms_file_slots.fetch(attribute.to_s.to_sym) do
        raise ArgumentError, "#{name}##{attribute} is not a declared file slot (inline_forms_file)"
      end
    end

    # All slot columns (filename, data, content_type of every slot), strings.
    def inline_forms_file_columns
      inline_forms_file_slots.flat_map { |attribute, slot| [ attribute.to_s, slot[:data], slot[:content_type] ] }
    end

    def inline_forms_merge_paper_trail_skip!
      return unless respond_to?(:paper_trail_options) && paper_trail_options.is_a?(Hash)

      skip = Array(paper_trail_options[:skip]).map(&:to_s)
      missing = inline_forms_file_columns - skip
      return if missing.empty?

      # Assign a new hash on this class: the options may be inherited from
      # ApplicationRecord (generated apps call has_paper_trail there), and
      # mutating that shared hash would skip these columns on every model.
      self.paper_trail_options = paper_trail_options.merge(skip: skip + missing)
    end

    def method_added(name)
      super
      return unless name.to_s.end_with?("=")

      attribute = name.to_s.delete_suffix("=").to_sym
      inline_forms_hand_written_setter!(attribute) if inline_forms_file_slot?(attribute)
    end

    private

    def inline_forms_file_setters
      @inline_forms_file_setters ||= Module.new.tap { |setters| prepend(setters) }
    end

    def inline_forms_hand_written_setter!(attribute)
      message = "#{name} defines its own `#{attribute}=` but #{attribute} is a declared file slot " \
                "(inline_forms_file); remove the hand-written setter (and its sanitize_filename) -- " \
                "the slot's setter replaces it."
      raise HandWrittenSetterError, message unless defined?(Rails) && Rails.env.production?

      Rails.logger&.warn("inline_forms: #{message}")
    end
  end

  # ---- reading --------------------------------------------------------------

  def inline_forms_file_present?(attribute)
    self[attribute.to_s].present?
  end

  # { data:, filename:, type: } read fresh from the DB, or nil when the slot
  # holds no bytes (an empty slot must 404, never send an empty file).
  def inline_forms_file_download(attribute)
    slot = self.class.inline_forms_file_slot(attribute)
    row = inline_forms_file_row(slot, attribute)
    return nil if row.nil? || row[0].nil?

    { data: row[0], filename: row[1].presence || "download", type: row[2].presence || "application/octet-stream" }
  end

  # ---- writing --------------------------------------------------------------

  # The edit form was submitted without a file: fail validation so the user
  # sees "no file chosen" instead of a silent no-op.
  def inline_forms_file_missing!(attribute)
    inline_forms_file_errors[attribute.to_sym] = [ :inline_forms_file_missing ]
  end

  # Moves the current file to the trash and clears the slot. Returns the
  # trash entry, or nil when the slot was already empty (double click, stale
  # page). Writes with update_columns: an unrelated invalid column on an old
  # record must not block taking a wrong file out.
  def inline_forms_remove_file!(attribute, by: InlineForms::Current.user_id, reason: :removed)
    slot = self.class.inline_forms_file_slot(attribute)
    self.class.transaction do
      row = inline_forms_file_row(slot, attribute, lock: true)
      if row && (row[0] || row[1].present?)
        entry = InlineForms::TrashedFile.trash!(
          record: self, attribute: attribute, data: row[0], filename: row[1],
          content_type: row[2], reason: reason, by: by
        )
        inline_forms_write_slot!(slot, attribute, nil, nil, nil)
        entry
      end
    end
  end

  # Writes bytes into the slot directly (restore, revert of a destroy). A file
  # already in the slot goes to the trash first. Caller holds the row lock.
  def inline_forms_put_file!(attribute, data:, filename:, content_type:, by: InlineForms::Current.user_id)
    slot = self.class.inline_forms_file_slot(attribute)
    current = inline_forms_file_row(slot, attribute)
    if current && current[0]
      InlineForms::TrashedFile.trash!(
        record: self, attribute: attribute, data: current[0], filename: current[1],
        content_type: current[2], reason: :replaced, by: by
      )
    end
    inline_forms_write_slot!(slot, attribute, data, filename, content_type)
  end

  private

  def inline_forms_staged_files
    @inline_forms_staged_files ||= {}
  end

  def inline_forms_file_errors
    @inline_forms_file_errors ||= {}
  end

  # The setter body. Yields for a String (a plain attribute write).
  def inline_forms_assign_file(attribute, value)
    return if value.nil?
    return yield if value.is_a?(String)

    unless value.respond_to?(:read) && value.respond_to?(:original_filename)
      inline_forms_file_errors[attribute] = [ :invalid ]
      return
    end

    bytes = value.read.to_s.b
    value.rewind if value.respond_to?(:rewind)
    max = InlineForms.max_file_size
    if max && bytes.bytesize > max
      inline_forms_file_errors[attribute] = [ :inline_forms_file_too_large, { count: max / 1.megabyte } ]
      return
    end

    inline_forms_file_errors.delete(attribute)
    slot = self.class.inline_forms_file_slot(attribute)
    write_attribute(slot[:data], bytes)
    write_attribute(slot[:content_type], value.respond_to?(:content_type) ? value.content_type.to_s.presence : nil)
    write_attribute(attribute, InlineForms::StoredFiles.sanitize_filename(value.original_filename))
    inline_forms_staged_files[attribute] = { checksum: Digest::SHA256.hexdigest(bytes), byte_size: bytes.bytesize }
  end

  def inline_forms_validate_staged_files
    inline_forms_file_errors.each do |attribute, (type, options)|
      errors.add(attribute, type, **(options || {}))
    end
  end

  # before_save, inside the save's transaction: the file being replaced goes
  # to the trash. Read from the DB under a row lock (not from memory, which
  # may be stale). An identical re-upload changes nothing and is not logged.
  def inline_forms_trash_replaced_files
    return if new_record? || inline_forms_staged_files.empty?

    inline_forms_staged_files.each do |attribute, staged|
      slot = self.class.inline_forms_file_slot(attribute)
      old = inline_forms_file_row(slot, attribute, lock: true)
      next if old.nil? || old[0].nil?

      if Digest::SHA256.hexdigest(old[0]) == staged[:checksum]
        staged[:unchanged] = true
        next
      end
      InlineForms::TrashedFile.trash!(
        record: self, attribute: attribute, data: old[0], filename: old[1],
        content_type: old[2], reason: :replaced, by: InlineForms::Current.user_id
      )
    end
  end

  def inline_forms_record_uploaded_files
    staged = inline_forms_staged_files
    @inline_forms_staged_files = {}
    staged.each do |attribute, info|
      next if info[:unchanged]

      slot = self.class.inline_forms_file_slot(attribute)
      InlineForms::TrashedFile.record_upload!(
        record: self, attribute: attribute, filename: self[attribute.to_s],
        content_type: self[slot[:content_type]], byte_size: info[:byte_size],
        checksum: info[:checksum], by: InlineForms::Current.user_id
      )
    end
  end

  def inline_forms_trash_files_on_destroy
    self.class.inline_forms_file_slots.each do |attribute, slot|
      data = attribute_in_database(slot[:data])
      next if data.nil?

      InlineForms::TrashedFile.trash!(
        record: self, attribute: attribute, data: data,
        filename: attribute_in_database(attribute.to_s),
        content_type: attribute_in_database(slot[:content_type]),
        reason: :record_destroyed, by: InlineForms::Current.user_id
      )
    end
  end

  # [data, filename, content_type] from the DB, or nil when the row is gone.
  def inline_forms_file_row(slot, attribute, lock: false)
    scope = self.class.unscoped.where(self.class.primary_key => id)
    scope = scope.lock if lock
    scope.pluck(slot[:data], attribute.to_s, slot[:content_type]).first
  end

  def inline_forms_write_slot!(slot, attribute, data, filename, content_type)
    columns = { slot[:data] => data, attribute.to_s => filename, slot[:content_type] => content_type }
    columns["updated_at"] = Time.current if has_attribute?(:updated_at)
    update_columns(columns)
  end
end
