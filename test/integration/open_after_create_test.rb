# frozen_string_literal: true

require_relative "../integration_test_helper"

# "Open after create" (stuff/2026-07-10-nested-creation-options.md, Option A):
# a successful top-level create of a class with an :associated (has_many)
# panel responds with Turbo Streams that refresh the list and open the new
# record's row, so the nested panel is immediately usable. Everything else
# (classes without :associated, nested creates, failed saves, non-stream
# clients) keeps the plain frame responses.
class OpenAfterCreateTest < InlineFormsIntegrationTestCase
  # Turbo form submissions advertise turbo-stream before text/html.
  def stream_headers(frame_id)
    { "Turbo-Frame" => frame_id,
      "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  test "top-level create with an associated panel streams the list and the opened row" do
    assert_difference -> { Machine.count }, +1 do
      post machines_path(update: "machines_list"),
           params: { name: "Lathe" },
           headers: stream_headers("machines_list")
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type

    machine = Machine.find_by!(name: "Lathe")
    assert_includes response.body,
      %(<turbo-stream action="replace" target="machines_list">)
    assert_includes response.body,
      %(<turbo-stream action="replace" target="machine_#{machine.id}">)

    # The opened row exposes the parts panel with its "new part" link,
    # carrying the freshly created parent's id.
    assert_includes response.body, %(id="machine_#{machine.id}_parts_list_auto_header")
    assert_match(
      %r{/parts/new\?[^"]*parent_id=#{machine.id}},
      response.body,
      "expected the associated panel's new-record link for the created parent"
    )
  end

  test "top-level create without turbo-stream accept keeps the list frame response" do
    post machines_path(update: "machines_list"),
         params: { name: "Mill" },
         headers: frame_headers("machines_list")
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, %(<turbo-frame id="machines_list">)
  end

  test "create of a class without an associated panel is unchanged" do
    post parts_path(update: "parts_list"),
         params: { name: "Plain" },
         headers: stream_headers("parts_list")
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, %(<turbo-frame id="parts_list">)
  end

  test "nested create under a parent keeps the frame response" do
    machine = Machine.create!(name: "Host")
    frame = "machine_#{machine.id}_parts"

    assert_difference -> { Part.count }, +1 do
      post parts_path(update: frame, parent_class: "Machine", parent_id: machine.id),
           params: { name: "Bolt" },
           headers: stream_headers(frame)
    end
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal machine.id, Part.find_by!(name: "Bolt").machine_id
  end

  test "failed top-level create re-renders the new form, not streams" do
    assert_no_difference -> { Machine.count } do
      post machines_path(update: "machines_list"),
           params: { name: "" },
           headers: stream_headers("machines_list")
    end
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, 'class="edit_form"'
  end
end
