# frozen_string_literal: true

require_relative "../integration_test_helper"

# Declared file slots (InlineForms::StoredFiles) and the file trash:
# upload / replace / remove / restore / purge, permissions per action, the
# per-record panel, versions history, revert interplay, the retention sweep
# and the global trash page. Dummy model: Document (test/dummy).
class FileSlotsTest < InlineFormsIntegrationTestCase
  PLAN = "%PDF-1.4 the plan \x00\x01".b
  OTHER = "%PDF-1.4 another file \x02\x03".b

  setup do
    @doc = Document.create!(title: "Dossier A")
    @frame = "document_#{@doc.id}_filename"
  end

  def upload(bytes, name = "plan.pdf", type = "application/pdf")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)
  end

  def stream_headers(frame)
    frame_headers(frame).merge("Accept" => "text/vnd.turbo-stream.html")
  end

  def put_file(doc, attribute, value)
    frame = "document_#{doc.id}_#{attribute}"
    patch document_path(doc, attribute: attribute, form_element: "simple_file_field", update: frame),
          params: { attribute => value }, headers: frame_headers(frame)
  end

  def with_file(bytes = PLAN, name = "plan.pdf")
    @doc.update!(filename: upload(bytes, name))
    @doc.reload
  end

  def trash
    InlineForms::TrashedFile.trash_entries
  end

  # ---- declaration ------------------------------------------------------

  test "slot columns are skipped by PaperTrail on the model only" do
    skip_list = Document.paper_trail_options[:skip]
    %w[filename data content_type plan_filename plan_data plan_content_type].each do |column|
      assert_includes skip_list, column
    end
    refute_includes Widget.paper_trail_options[:skip], "data",
      "the inherited ApplicationRecord options must not be mutated"
  end

  test "default column names follow the attribute" do
    assert_equal({ data: "data", content_type: "content_type" }, Document.inline_forms_file_slot(:filename))
    assert_equal({ data: "plan_data", content_type: "plan_content_type" }, Document.inline_forms_file_slot(:plan_filename))
  end

  test "a hand-written setter for a declared slot raises outside production" do
    assert_raises(InlineForms::StoredFiles::HandWrittenSetterError) do
      Class.new(ApplicationRecord) do
        self.table_name = "documents"
        include InlineForms::StoredFiles
        inline_forms_file :filename
        def filename=(value); end
      end
    end
  end

  test "has_paper_trail after the macro still skips the slot columns" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "documents"
      include InlineForms::StoredFiles
      inline_forms_file :filename
      has_paper_trail
    end
    assert_includes klass.paper_trail_options[:skip], "data"
  end

  # ---- upload / replace ---------------------------------------------------

  test "uploading into an empty slot stores bytes and logs an upload event" do
    put_file @doc, "filename", upload(PLAN, "my plan (v2).pdf")

    assert_response :success
    @doc.reload
    assert_equal PLAN, @doc.data
    assert_equal "my_plan__v2_.pdf", @doc.filename
    assert_equal "application/pdf", @doc.content_type
    event = InlineForms::TrashedFile.events.sole
    assert_equal "filename", event.attribute_name
    assert_nil event.data
    assert_equal 1, event.trashed_by_id
    assert_empty trash
  end

  test "replacing moves the old bytes to the trash" do
    with_file
    put_file @doc, "filename", upload(OTHER, "other.pdf")

    assert_response :success
    assert_equal OTHER, @doc.reload.data
    entry = trash.sole
    assert_equal "replaced", entry.reason
    assert_equal PLAN, entry.file_data
    assert_equal "plan.pdf", entry.filename
    assert_equal Digest::SHA256.hexdigest(PLAN), entry.checksum
    assert_in_delta 30.days.from_now, entry.purge_after, 5
  end

  test "re-uploading identical bytes trashes nothing" do
    with_file
    put_file @doc, "filename", upload(PLAN, "plan.pdf")

    assert_response :success
    assert_empty trash
  end

  test "replace needs :replace_file; an empty slot only needs :update" do
    Ability.restrictions = -> { cannot :replace_file, Document }
    put_file @doc, "plan_filename", upload(PLAN)
    assert_response :success

    with_file
    put_file @doc, "filename", upload(OTHER, "other.pdf")
    assert_response :forbidden
    assert_equal PLAN, @doc.reload.data
    assert_empty trash
  end

  test "edit of an occupied slot needs :replace_file too" do
    with_file
    Ability.restrictions = -> { cannot :replace_file, Document }
    get edit_document_path(@doc, attribute: "filename", form_element: "simple_file_field", update: @frame),
        headers: frame_headers(@frame)
    assert_response :forbidden
  end

  test "a crafted string for a slot is refused as 'no file chosen'" do
    with_file
    put_file @doc, "filename", "evil.exe"

    assert_response :success
    assert_includes response.body, "no file chosen"
    @doc.reload
    assert_equal "plan.pdf", @doc.filename
    assert_equal PLAN, @doc.data
  end

  test "an upload above max_file_size is a validation error" do
    InlineForms.max_file_size = 10
    put_file @doc, "filename", upload(PLAN)

    assert_includes response.body, "is too large"
    assert_nil @doc.reload.data
  end

  test "a failed save does not leave a trash row behind" do
    with_file
    Document.where(id: @doc.id).update_all(title: nil) # an unrelated invalid column
    put_file @doc, "filename", upload(OTHER, "other.pdf")

    assert_includes response.body, "can"
    assert_equal PLAN, @doc.reload.data
    assert_empty trash
  end

  # ---- show ---------------------------------------------------------------

  test "a present slot renders download, replace and remove; an empty one the plus link" do
    with_file
    get document_path(@doc, attribute: "filename", form_element: "simple_file_field", update: @frame),
        headers: frame_headers(@frame)

    assert_response :success
    assert_includes response.body, download_file_document_path(@doc, attribute: "filename")
    assert_includes response.body, remove_file_document_path(@doc, attribute: "filename")
    assert_includes response.body, "fi-pencil"
    assert_includes response.body, "data-turbo-confirm"
  end

  test "remove and replace icons follow the permissions" do
    with_file
    Ability.restrictions = -> { cannot [ :remove_file, :replace_file ], Document }
    get document_path(@doc, attribute: "filename", form_element: "simple_file_field", update: @frame),
        headers: frame_headers(@frame)

    refute_includes response.body, "remove_file"
    refute_includes response.body, "fi-pencil"
    assert_includes response.body, "download_file"
  end

  test "the record shows a trash panel frame and file events in versions" do
    with_file
    @doc.inline_forms_remove_file!(:filename, by: 1)
    row = "document_#{@doc.id}"
    get document_path(@doc, update: row), headers: frame_headers(row)

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="document_#{@doc.id}_file_trash">)
    assert_includes response.body, "Removed files (1)"
    assert_includes response.body, "Versions (3)", "create version + upload event + removal event"
  end

  # ---- remove / restore / purge -----------------------------------------

  test "remove moves the file to the trash and offers undo" do
    with_file
    post remove_file_document_path(@doc, attribute: "filename", update: @frame), headers: stream_headers(@frame)

    assert_response :success
    @doc.reload
    assert_nil @doc.filename
    assert_nil @doc.data
    entry = trash.sole
    assert_equal "removed", entry.reason
    assert_equal PLAN, entry.file_data
    assert_includes response.body, "plan.pdf removed"
    assert_includes response.body, "plan.pdf removed"
    assert_equal 1, response.body.scan("trash_id=#{entry.id}").size, "one undo link: the notice's, not also the plus link's"
    assert_includes response.body, %(target="document_#{@doc.id}_file_trash")
    assert_includes response.body, %(target="document_#{@doc.id}_versions")
  end

  test "removing an empty slot twice creates no empty trash row" do
    post remove_file_document_path(@doc, attribute: "filename", update: @frame), headers: stream_headers(@frame)
    assert_response :success
    assert_empty trash
  end

  test "remove works on a record that fails unrelated validations" do
    with_file
    Document.where(id: @doc.id).update_all(title: nil)
    post remove_file_document_path(@doc, attribute: "filename", update: @frame), headers: stream_headers(@frame)

    assert_response :success
    assert_nil @doc.reload.data
  end

  test "remove needs :remove_file" do
    with_file
    Ability.restrictions = -> { cannot :remove_file, Document }
    post remove_file_document_path(@doc, attribute: "filename", update: @frame), headers: stream_headers(@frame)

    assert_response :forbidden
    assert_equal PLAN, @doc.reload.data
  end

  test "an undeclared attribute is refused" do
    post remove_file_document_path(@doc, attribute: "title", update: @frame), headers: stream_headers(@frame)
    assert_response :bad_request
  end

  test "restore puts the bytes back and empties the trash row" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    post restore_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_response :success
    @doc.reload
    assert_equal PLAN, @doc.data
    assert_equal "plan.pdf", @doc.filename
    entry.reload
    assert entry.restored?
    assert_nil entry.file_data
  end

  test "restore into an occupied slot swaps: the current file goes to the trash" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    with_file(OTHER, "other.pdf")
    post restore_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_equal PLAN, @doc.reload.data
    swapped = trash.where(reason: "replaced").sole
    assert_equal OTHER, swapped.file_data
  end

  test "restore twice is a no-op the second time" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    2.times do
      post restore_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
           headers: stream_headers(@frame)
    end

    assert_includes response.body, "can no longer be restored"
    assert_equal 1, trash.count
  end

  test "restore needs :restore_file, and :update for an empty slot" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    Ability.restrictions = -> { cannot :update, Document, [ :filename ] }
    post restore_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_response :forbidden
    assert_nil @doc.reload.data
  end

  test "a trash entry of another record is not found" do
    other = Document.create!(title: "Dossier B", filename: upload(PLAN))
    entry = other.inline_forms_remove_file!(:filename, by: 1)
    post restore_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_response :not_found
    assert entry.reload.trashed?
  end

  test "purge deletes the bytes and keeps the tombstone" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    post purge_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_response :success
    entry.reload
    assert entry.purged?
    assert_nil entry.file_data
    assert_equal "plan.pdf", entry.filename, "no redaction by default"
    assert_equal Digest::SHA256.hexdigest(PLAN), entry.checksum
  end

  test "purge with redaction blanks the filename" do
    InlineForms.file_trash_redact_on_purge = true
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    assert entry.purge!(by: 1)

    assert_nil entry.reload.filename
    assert entry.redacted?
  end

  test "purge needs :purge_file" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    Ability.restrictions = -> { cannot :purge_file, Document }
    post purge_file_document_path(@doc, attribute: "filename", trash_id: entry.id, update: @frame),
         headers: stream_headers(@frame)

    assert_response :forbidden
    assert entry.reload.trashed?
  end

  test "a purged entry can be neither restored nor purged again" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    assert entry.purge!(by: 1)

    refute entry.purge!(by: 1)
    assert_raises(InlineForms::TrashedFile::NotRestorable) { entry.restore!(by: 1) }
  end

  # ---- downloads --------------------------------------------------------

  test "download_file sends the bytes as an attachment, never cached" do
    with_file
    get download_file_document_path(@doc, attribute: "filename")

    assert_response :success
    assert_equal PLAN, response.body.b
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "download_file of an empty slot is a 404, not an empty file" do
    get download_file_document_path(@doc, attribute: "filename")
    assert_response :not_found
  end

  test "download_file needs :read on the attribute" do
    with_file
    Ability.restrictions = -> { cannot :read, Document, [ :filename ] }
    get download_file_document_path(@doc, attribute: "filename")
    assert_response :forbidden
  end

  test "a trashed file downloads as octet-stream attachment until purged" do
    with_file(PLAN, "page.html")
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    get trashed_file_document_path(@doc, attribute: "filename", trash_id: entry.id)

    assert_response :success
    assert_equal PLAN, response.body.b
    assert_equal "application/octet-stream", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    entry.purge!(by: 1)
    get trashed_file_document_path(@doc, attribute: "filename", trash_id: entry.id)
    assert_response :not_found
  end

  test "downloading a trashed file needs :download_trashed_file" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    Ability.restrictions = -> { cannot :download_trashed_file, Document }
    get trashed_file_document_path(@doc, attribute: "filename", trash_id: entry.id)
    assert_response :forbidden
  end

  # ---- panel --------------------------------------------------------------

  test "the open panel lists entries with actions; closed shows the count" do
    with_file
    @doc.inline_forms_remove_file!(:filename, by: 1)
    panel = "document_#{@doc.id}_file_trash"
    get file_trash_document_path(@doc, update: panel, slots: "filename,plan_filename"), headers: frame_headers(panel)

    assert_response :success
    assert_includes response.body, "plan.pdf"
    assert_includes response.body, "delete permanently"
    assert_includes response.body, "restorable until"
  end

  test "the panel needs :read_file_trash" do
    Ability.restrictions = -> { cannot :read_file_trash, Document }
    panel = "document_#{@doc.id}_file_trash"
    get file_trash_document_path(@doc, update: panel), headers: frame_headers(panel)
    assert_response :forbidden
  end

  # ---- destroy / revert --------------------------------------------------

  test "destroying a record trashes its files; undoing the destroy brings them back" do
    Document.require_filename = true
    with_file
    @doc.update!(plan_filename: upload(OTHER, "plan2.pdf"))
    row = "document_#{@doc.id}"
    delete document_path(@doc, update: row), headers: frame_headers(row)
    assert_equal 2, trash.where(reason: "record_destroyed").count

    version = PaperTrail::Version.where(item_type: "Document", item_id: @doc.id, event: "destroy").last
    post revert_document_path(version.id, update: "documents_list"), headers: stream_headers("documents_list")

    assert_response :success
    restored = Document.find(@doc.id)
    assert_equal PLAN, restored.data
    assert_equal "plan.pdf", restored.filename
    assert_equal OTHER, restored.plan_data
    assert trash.where(reason: "record_destroyed").all?(&:restored?)
  end

  test "undoing a destroy after a purge brings the record back without that file" do
    with_file
    row = "document_#{@doc.id}"
    delete document_path(@doc, update: row), headers: frame_headers(row)
    trash.sole.purge!(by: 1)

    version = PaperTrail::Version.where(item_type: "Document", item_id: @doc.id, event: "destroy").last
    post revert_document_path(version.id, update: "documents_list"), headers: stream_headers("documents_list")

    restored = Document.find(@doc.id)
    assert_nil restored.filename
    assert_nil restored.data
  end

  test "reverting an update never touches a slot, even from an old version carrying a filename" do
    with_file
    @doc.update!(title: "Renamed")
    version = PaperTrail::Version.where(item_type: "Document", item_id: @doc.id, event: "update").last
    # A pre-adoption version row still has the slot columns in it.
    version.update_columns(object: version.object.sub("title: Dossier A", "title: Dossier A\nfilename: old.pdf"))

    post revert_document_path(version.id, update: "document_#{@doc.id}"), headers: stream_headers("document_#{@doc.id}")

    assert_response :success
    @doc.reload
    assert_equal "Dossier A", @doc.title
    assert_equal "plan.pdf", @doc.filename
    assert_equal PLAN, @doc.data
  end

  # ---- retention ----------------------------------------------------------

  test "an expired entry is no longer restorable and the sweep purges it" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    entry.update_columns(purge_after: 1.minute.ago)

    assert_raises(InlineForms::TrashedFile::NotRestorable) { entry.reload.restore!(by: 1) }
    assert_equal 1, InlineForms::FileTrashSweep.run!
    assert entry.reload.purged?
    assert_nil entry.purged_by_id
    refute InlineForms::FileTrashSweep.overdue?
  end

  test "retention nil never expires" do
    InlineForms.file_trash_retention = nil
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    assert_nil entry.purge_after
    assert_equal 0, InlineForms::TrashedFile.purge_expired!
  end

  test "the sweep is overdue when it never ran" do
    assert InlineForms::FileTrashSweep.overdue?
  end

  # ---- global page ----------------------------------------------------------

  test "the global page lists trashed files and bulk-purges selected ones" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    get inline_forms_file_trash_path

    assert_response :success
    assert_includes response.body, "plan.pdf"

    post inline_forms_file_trash_purge_path, params: { ids: [ entry.id ] }
    assert_response :redirect
    assert entry.reload.purged?
  end

  test "the global page offers bulk purge only when a listed row is purgeable" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    get inline_forms_file_trash_path(state: "trashed")
    assert_includes response.body, %(id="trash_entry_#{entry.id}")
    assert_includes response.body, I18n.t("inline_forms.files.global.purge_selected")

    entry.restore!(by: 1)
    get inline_forms_file_trash_path(state: "restored")
    assert_includes response.body, "plan.pdf"
    refute_includes response.body, %(name="ids[]")
    refute_includes response.body, I18n.t("inline_forms.files.global.purge_selected")
  end

  test "the global page restores and downloads" do
    with_file
    entry = @doc.inline_forms_remove_file!(:filename, by: 1)
    get inline_forms_file_trash_download_path(entry)
    assert_equal PLAN, response.body.b

    post inline_forms_file_trash_restore_path(entry)
    assert_response :redirect
    assert_equal PLAN, @doc.reload.data
  end

  test "the global page purges files of deleted records" do
    with_file
    row = "document_#{@doc.id}"
    delete document_path(@doc, update: row), headers: frame_headers(row)
    entry = trash.sole

    post inline_forms_file_trash_purge_path, params: { ids: [ entry.id ] }
    assert entry.reload.purged?
  end

  test "the global page needs :read_file_trash on :all" do
    Ability.restrictions = lambda do
      cannot :manage, :all
      can :read, :all
      can :read_file_trash, Document
    end
    get inline_forms_file_trash_path
    assert_response :forbidden
  end

  test "a bulk purge is all or nothing when one row is not allowed" do
    with_file
    mine = @doc.inline_forms_remove_file!(:filename, by: 1)
    @doc.update!(plan_filename: upload(OTHER, "x.pdf"))
    theirs = @doc.inline_forms_remove_file!(:plan_filename, by: 1)
    Ability.restrictions = -> { cannot :purge_file, Document, [ :plan_filename ] }

    post inline_forms_file_trash_purge_path, params: { ids: [ mine.id, theirs.id ] }

    assert_response :forbidden
    assert mine.reload.trashed?
    assert theirs.reload.trashed?
  end
end
