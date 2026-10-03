# -*- encoding : utf-8 -*-

# View helpers for declared file slots (InlineForms::StoredFiles): the field's
# file actions, the per-record trash panel and file events in the versions
# history. Every permission check fails closed: with CanCan on, nothing is
# offered unless the Ability grants it.
module InlineFormsFileTrashHelper
  # True when +attribute+ is a declared slot AND the host routed the file
  # actions for this resource (InlineForms.file_routes). Without the routes
  # the field renders exactly as before (legacy download link, no actions).
  def inline_forms_file_slot_active?(object, attribute)
    klass = object.class
    klass.respond_to?(:inline_forms_file_slot?) &&
      klass.inline_forms_file_slot?(attribute) &&
      object.persisted? &&
      respond_to?("download_file_#{object.model_name.singular_route_key}_path")
  end

  def inline_forms_file_can?(action, object, attribute = nil)
    return true if inline_forms_cancan_off?

    attribute ? can?(action, object, attribute.to_sym) : can?(action, object)
  end

  # Declared, routed slots among the rows of the attribute list being shown
  # (a Client tab shows only its own slots).
  def inline_forms_file_trash_slots(object, attributes = nil)
    attributes ||= @inline_forms_attribute_list || object.inline_forms_attribute_list
    attributes.filter_map do |attribute, form_element, *|
      next unless form_element.to_s == "simple_file_field"
      next unless inline_forms_file_slot_active?(object, attribute)
      next unless inline_forms_file_can?(:read_file_trash, object, attribute)

      attribute.to_s
    end
  end

  # Menu link to the global trash page, for hosts with their own header.
  # Renders nothing unless the routes exist and the user may read all trash.
  def link_to_inline_forms_file_trash(label = nil, **options)
    return unless respond_to?(:inline_forms_file_trash_path)
    return unless inline_forms_cancan_off? || can?(:read_file_trash, :all)

    link_to(label || t("inline_forms.files.global.title"), inline_forms_file_trash_path, options)
  end

  # cancan_disabled? is a helper of the engine's controllers only; a layout
  # rendered by any other controller still has CanCan's can? when CanCan is on.
  def inline_forms_cancan_off?
    return cancan_disabled? if respond_to?(:cancan_disabled?)

    !respond_to?(:can?)
  end

  def inline_forms_file_field_frame_id(object, attribute)
    "#{object.class.name.underscore}_#{object.id}_#{attribute}"
  end

  def inline_forms_file_trash_turbo_frame_id(object)
    "#{inline_forms_row_turbo_frame_id(object)}_file_trash"
  end

  def inline_forms_file_size(bytes)
    bytes ? number_to_human_size(bytes) : ""
  end

  # Icon-only link: the label goes to title and aria-label, the icon is
  # hidden from assistive tech.
  def inline_forms_file_icon_link(icon, label, path, options = {})
    options = options.merge(title: label, "aria-label": label)
    link_to tag.i(class: icon, "aria-hidden": "true"), path, options
  end

  # data-* for a POST link that answers with turbo streams (field, trash
  # panel and versions frames are replaced together), with a confirm dialog.
  def inline_forms_file_post_data(frame_id, confirm: nil)
    data = inline_forms_turbo_link_data(frame_id, method: :post, turbo_stream: true)
    data[:data][:turbo_confirm] = confirm if confirm
    data
  end

  def inline_forms_file_retention_days
    retention = InlineForms.file_trash_retention
    retention && (retention / 1.day).round
  end

  def inline_forms_file_user_name(id)
    return t("inline_forms.files.by_system") if id.blank?

    version_modified_by(id)
  rescue StandardError
    id.to_s
  end

  # The filename to show for a trash row (a redacted row shows a label).
  def inline_forms_file_entry_name(entry)
    entry.redacted? ? t("inline_forms.files.redacted_name") : entry.filename.to_s
  end

  # Newest restorable trash entry for each slot, keyed by attribute name.
  def inline_forms_restorable_file_entries(object, slots)
    return {} if slots.empty?

    InlineForms::TrashedFile.without_data.for_record(object).where(attribute_name: slots)
      .restorable.newest_first.each_with_object({}) do |entry, by_slot|
        by_slot[entry.attribute_name] ||= entry
      end
  end

  # The versions history: PaperTrail versions (inline_forms_versions_for,
  # which hosts may override) plus file events from the trash table, each
  # entry carrying :at for sorting. File events show only to users who may
  # read the trash.
  def inline_forms_history_for(object)
    entries = inline_forms_versions_for(object).map { |entry| entry.merge(at: entry[:version].created_at) }
    entries.concat(inline_forms_file_history_entries(object))
    entries.sort_by { |entry| entry[:at] }
  end

  def inline_forms_file_history_entries(object)
    slots = inline_forms_file_trash_slots(object)
    return [] if slots.empty?

    InlineForms::TrashedFile.without_data.for_record(object).where(attribute_name: slots).flat_map do |row|
      events = [ { kind: :file, file_event: row.reason.to_sym, at: row.trashed_at, by: row.trashed_by_id, entry: row } ]
      events << { kind: :file, file_event: :restored, at: row.restored_at, by: row.restored_by_id, entry: row } if row.restored?
      events << { kind: :file, file_event: :purged, at: row.purged_at, by: row.purged_by_id, entry: row } if row.purged?
      events
    end
  end
end
