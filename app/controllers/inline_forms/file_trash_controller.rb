# -*- encoding : utf-8 -*-

# The cross-record file trash (superadmin): every trashed file of every model,
# filterable, with download / restore / purge and a bulk purge. It is also the
# only place to purge files whose record was deleted, and it shows the
# retention sweep's heartbeat. Routed by InlineForms.draw_file_trash_routes.
#
# Access: authorize!(:read_file_trash, :all) -- granted by `can :manage, :all`
# (superadmin), never by `can :read, :all` (a different action) or by
# per-model grants. Each row action is authorized again against the file's
# record (or, when the record is gone, its class) and attribute.
class InlineForms::FileTrashController < ::ApplicationController
  include CancanConcern

  layout "inline_forms"

  before_action { InlineForms::Current.user_id = current_user_id }
  before_action { authorize!(:read_file_trash, :all) if cancan_enabled? }

  STATES = %w[trashed expired restored purged all].freeze
  PER_PAGE = 50

  def index
    @models = InlineForms::TrashedFile.trash_entries.distinct.pluck(:record_type).sort
    @model = params[:model].presence_in(@models)
    @state = params[:state].presence_in(STATES) || "trashed"
    @entries = filtered_entries.paginate(page: params[:page], per_page: PER_PAGE)
    @last_sweep = InlineForms::FileTrashSweep.last_run
    @sweep_overdue = InlineForms::FileTrashSweep.overdue?
  end

  # Bulk purge of the checked rows: one transaction, every row authorized
  # (any refusal rolls the whole request back).
  def purge
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    return redirect_to(back_to_index, alert: t("inline_forms.files.global.nothing_selected")) if ids.empty?

    purged = 0
    InlineForms::TrashedFile.transaction do
      InlineForms::TrashedFile.without_data.trash_entries.where(id: ids).each do |entry|
        authorize_entry!(:purge_file, entry)
        purged += 1 if entry.purge!(by: current_user_id)
      end
    end
    redirect_to back_to_index, notice: t("inline_forms.files.global.purged_count", count: purged)
  end

  def restore
    entry = find_entry
    record = entry.owner
    return redirect_to(back_to_index, alert: t("inline_forms.files.notice_not_restorable")) unless record

    authorize_entry!(:restore_file, entry, record)
    if cancan_enabled?
      authorize!(record.inline_forms_file_present?(entry.attribute_name) ? :replace_file : :update,
                 record, entry.attribute_name.to_sym)
    end
    entry.restore!(by: current_user_id)
    redirect_to back_to_index, notice: t("inline_forms.files.notice_restored")
  rescue InlineForms::TrashedFile::NotRestorable
    redirect_to back_to_index, alert: t("inline_forms.files.notice_not_restorable")
  end

  def download
    entry = find_entry
    authorize_entry!(:download_trashed_file, entry)
    data = entry.trashed? ? entry.file_data : nil
    return render(plain: t("inline_forms.files.missing"), status: :not_found) if data.nil?

    Rails.logger.info(
      "inline_forms file_trash download entry=#{entry.id} #{entry.record_type}##{entry.record_id}." \
      "#{entry.attribute_name} user=#{current_user_id.inspect}"
    )
    response.headers["Cache-Control"] = "no-store"
    send_data data, filename: entry.filename.presence || "file", type: "application/octet-stream", disposition: :attachment
  end

  private

  def filtered_entries
    scope = InlineForms::TrashedFile.without_data.trash_entries.newest_first
    scope = scope.where(record_type: @model) if @model
    case @state
    when "trashed"  then scope.restorable
    when "expired"  then scope.still_trashed.expired
    when "restored" then scope.where.not(restored_at: nil)
    when "purged"   then scope.where.not(purged_at: nil)
    else scope
    end
  end

  def find_entry
    InlineForms::TrashedFile.without_data.trash_entries.find(params[:id])
  end

  # Against the record when it still exists, else its class: a grant like
  # `can :purge_file, Client` then still covers files of deleted clients.
  def authorize_entry!(action, entry, record = entry.owner)
    return unless cancan_enabled?

    subject = record || entry.owner_class
    raise CanCan::AccessDenied.new(nil, action, entry) unless subject

    authorize!(action, subject, entry.attribute_name.to_sym)
  end

  def back_to_index
    inline_forms_file_trash_path(params.permit(:model, :state, :page).to_h.compact_blank)
  end

  def current_user_id
    user = respond_to?(:current_user, true) ? current_user : nil
    user.respond_to?(:id) ? user.id : nil
  end
end
