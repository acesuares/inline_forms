# frozen_string_literal: true

require_relative "../integration_test_helper"

# Reverting a version must leave columns excluded via `has_paper_trail skip:`
# alone. PaperTrail's reify defaults to `unversioned_attributes: :nil`, which
# set every skipped column to nil on the live record; revert's save! then
# persisted that, so in StProject reverting any Client edit NULLed the file
# bytes (`*_data`) while keeping `*_filename` (downloads returned empty files).
class RevertSkippedColumnsTest < InlineFormsIntegrationTestCase
  BYTES = "%PDF-1.4 fake bytes \x00\x01\x02".b

  setup do
    @dossier = Dossier.create!(name: "Original", data_filename: "plan.pdf", data: BYTES)
  end

  def turbo_stream_headers(frame_id)
    frame_headers(frame_id).merge("Accept" => "text/vnd.turbo-stream.html")
  end

  def versions_for(event)
    PaperTrail::Version.where(item_type: "Dossier", item_id: @dossier.id, event: event)
  end

  test "the skipped column is really not versioned" do
    refute_includes versions_for("create").last.object_changes.to_s, "fake bytes"
  end

  test "reverting an unrelated update keeps the skipped column's bytes" do
    @dossier.update!(name: "Renamed")
    update_version = versions_for("update").last
    frame = "dossier_#{@dossier.id}"

    post revert_dossier_path(update_version.id, update: frame),
         headers: turbo_stream_headers(frame)

    assert_response :success
    @dossier.reload
    assert_equal "Original", @dossier.name, "revert must restore the versioned attribute"
    assert_equal "plan.pdf", @dossier.data_filename
    assert_equal BYTES, @dossier.data, "revert must not NULL a has_paper_trail skip: column"
  end

  test "replaying a destroy revert on an existing row keeps the skipped column's bytes" do
    frame = "dossier_#{@dossier.id}"
    delete dossier_path(@dossier, update: frame), headers: frame_headers(frame)
    destroy_version = versions_for("destroy").last
    # The destroy snapshot cannot hold the bytes (skipped); put the row back
    # with its file, as the user would after the first undo + re-upload.
    Dossier.create!(id: @dossier.id, name: "Original", data_filename: "plan.pdf", data: BYTES)

    post revert_dossier_path(destroy_version.id, update: "dossiers_list"),
         headers: turbo_stream_headers("dossiers_list")

    assert_response :success
    assert_equal BYTES, Dossier.find(@dossier.id).data,
      "idempotent destroy revert must not copy a nil skipped column onto the live row"
  end
end
