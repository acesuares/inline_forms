# -*- encoding : utf-8 -*-

# Actions for declared file slots (InlineForms::StoredFiles) on a record:
# download, remove, restore (undo), purge, download a trashed file, and the
# per-record trash panel. Routed by InlineForms.file_routes(self) inside the
# resource block.
#
# Every action is excluded from load_and_authorize_resource and authorizes
# itself, attribute-level, because CanCanCan skips attribute-scoped rules
# when no attribute is given:
#
#   download_file   :read            on the record + attribute
#   remove_file     :remove_file     on the record + attribute
#   restore_file    :restore_file    + :replace_file (slot occupied) or
#                                      :update (slot empty) on the attribute
#   purge_file      :purge_file      on the record + attribute
#   trashed_file    :download_trashed_file on the record + attribute
#   file_trash      :read_file_trash on the record (each slot filtered)
#
# The attribute must be a declared slot that the model's attribute list shows
# as :simple_file_field (400 otherwise); a trash entry must belong to this
# record and attribute (404 otherwise), so ids can't be guessed across records.
module FileSlotsConcern
  extend ActiveSupport::Concern

  FILE_SLOT_ACTIONS = %i[download_file remove_file restore_file purge_file trashed_file file_trash].freeze

  included do
    before_action :set_inline_forms_current_user
    helper_method :inline_forms_file_trash_slots_param
  end

  def download_file
    @object = referenced_object
    return unless file_slot_request_permitted?(:read)

    file = @object.inline_forms_file_download(@attribute)
    return render_missing_file unless file

    send_inline_forms_file(file)
  end

  def remove_file
    @object = referenced_object
    return unless file_slot_request_permitted?(:remove_file)

    @file_entry = @object.inline_forms_remove_file!(@attribute, by: inline_forms_current_user_id)
    @file_notice = @file_entry ? :removed : :already_empty
    render_file_slot_streams
  end

  def restore_file
    @object = referenced_object
    return unless file_slot_request_permitted?(:restore_file)

    entry = find_file_entry
    return head :not_found unless entry
    authorize!(@object.inline_forms_file_present?(@attribute) ? :replace_file : :update, @object, @attribute.to_sym) if cancan_enabled?

    begin
      entry.restore!(by: inline_forms_current_user_id)
      @object.reload
      @file_notice = :restored
    rescue InlineForms::TrashedFile::NotRestorable
      @file_notice = :not_restorable
    end
    render_file_slot_streams
  end

  def purge_file
    @object = referenced_object
    return unless file_slot_request_permitted?(:purge_file)

    entry = find_file_entry
    return head :not_found unless entry

    @file_notice = entry.purge!(by: inline_forms_current_user_id) ? :purged : :not_purgeable
    render_file_slot_streams
  end

  def trashed_file
    @object = referenced_object
    return unless file_slot_request_permitted?(:download_trashed_file)

    entry = find_file_entry
    return head :not_found unless entry
    return render_missing_file unless entry.trashed?

    data = entry.file_data
    return render_missing_file if data.nil?

    # Access to possibly mis-filed personal data: log who opened what.
    Rails.logger.info(
      "inline_forms file_trash download entry=#{entry.id} #{entry.record_type}##{entry.record_id}." \
      "#{entry.attribute_name} user=#{inline_forms_current_user_id.inspect}"
    )
    # Never render a trashed file inline (stored HTML/SVG would run on our
    # origin): always an attachment, always octet-stream.
    send_inline_forms_file({ data: data, filename: entry.filename.presence || "file", type: "application/octet-stream" })
  end

  def file_trash
    @object = referenced_object
    authorize!(:read_file_trash, @object) if cancan_enabled?
    @update_span = params[:update]
    @file_trash_slots = file_trash_slots_from_params
    @file_trash_open = params[:close].blank?
    render "inline_forms/file_trash_panel", layout: "turbo_rails/frame"
  end

  # For host download actions that predate download_file (e.g. a `dl` route
  # already linked from elsewhere):
  #   def dl
  #     @client = Client.find(params[:id])
  #     authorize! :read, @client, :filename
  #     send_inline_forms_file(@client.inline_forms_file_download(:filename)) or head :not_found
  #   end
  def send_inline_forms_file(file)
    return render_missing_file if file.nil?

    response.headers["Cache-Control"] = "no-store"
    send_data file[:data], filename: file[:filename], type: file[:type], disposition: :attachment
  end

  private

  def set_inline_forms_current_user
    InlineForms::Current.user_id = inline_forms_current_user_id
  end

  def inline_forms_current_user_id
    user = respond_to?(:current_user, true) ? current_user : nil
    user.respond_to?(:id) ? user.id : nil
  end

  # Validates the attribute (declared slot shown as :simple_file_field in the
  # attribute list), then authorizes +action+ on it. Renders and returns false
  # when refused.
  def file_slot_request_permitted?(action)
    @attribute = params[:attribute].to_s
    @form_element = "simple_file_field"
    @update_span = params[:update]
    unless inline_forms_file_slot_listed?(@object, @attribute)
      head :bad_request
      return false
    end
    authorize!(action, @object, @attribute.to_sym) if cancan_enabled?
    true
  end

  def inline_forms_file_slot_listed?(object, attribute)
    klass = object.class
    return false unless klass.respond_to?(:inline_forms_file_slot?) && klass.inline_forms_file_slot?(attribute)

    attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list
    InlineForms.attribute_list_row_for(attributes, attribute, "simple_file_field").present?
  end

  def find_file_entry
    InlineForms::TrashedFile.without_data.for_slot(@object, @attribute).trash_entries.find_by(id: params[:trash_id])
  end

  # The slots the trash panel lists: the ones the page passed (the current
  # tab's), reduced to declared, listed, readable slots.
  def file_trash_slots_from_params
    requested = params[:slots].to_s.split(",").map(&:strip).reject(&:empty?)
    requested = @object.class.inline_forms_file_slots.keys.map(&:to_s) if requested.empty? && @object.class.respond_to?(:inline_forms_file_slots)
    requested.select do |attribute|
      inline_forms_file_slot_listed?(@object, attribute) &&
        (cancan_disabled? || can?(:read_file_trash, @object, attribute.to_sym))
    end
  end

  def inline_forms_file_trash_slots_param
    Array(@file_trash_slots).join(",")
  end

  def render_missing_file
    render plain: t("inline_forms.files.missing"), status: :not_found
  end

  # The field, the record's trash panel and its versions panel all change
  # after a file action; replace the three frames in one response.
  def render_file_slot_streams
    @file_trash_slots = file_trash_slots_from_params
    @file_trash_open = params[:panel] == "open"
    field_id = "#{@object.class.name.underscore}_#{@object.id}_#{@attribute}"
    trash_id = helpers.inline_forms_file_trash_turbo_frame_id(@object)
    versions_id = helpers.inline_forms_versions_turbo_frame_id(@object)
    @inline_forms_turbo_field = true

    field_html = render_to_string("inline_forms/file_field_frame", layout: false, formats: [ :html ],
                                  locals: { frame_id: field_id })
    streams = [ turbo_stream.replace(field_id, field_html) ]
    # Only send the panels this user may see on the record page.
    if cancan_disabled? || can?(:read_file_trash, @object)
      trash_html = render_to_string("inline_forms/file_trash_panel", layout: false, formats: [ :html ],
                                    locals: { update_span: trash_id })
      streams << turbo_stream.replace(trash_id, trash_html)
    end
    if cancan_disabled? || can?(:list_versions, @object)
      versions_html = render_to_string("inline_forms/versions_panel", layout: false, formats: [ :html ],
                                       locals: { update_span: versions_id, object: @object })
      streams << turbo_stream.replace(versions_id, versions_html)
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html { render html: field_html, layout: "turbo_rails/frame" }
    end
  end
end
