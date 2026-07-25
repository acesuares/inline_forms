# frozen_string_literal: true

require_relative "../integration_test_helper"

# End-to-end (controller + views + Turbo frames) CRUD through the engine's
# InlineFormsController, running against the test/dummy host app.
class InlineFormsCrudTest < InlineFormsIntegrationTestCase
  setup do
    @widget = Widget.create!(name: "Alpha", priority: 2)
  end

  test "index lists rows inside the list turbo-frame" do
    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="widgets_list" class="list_container">)
    assert_includes response.body, %(<turbo-frame id="widget_#{@widget.id}">)
    assert_includes response.body, "Alpha"
  end

  test "index applies inline_forms_search when ?search= is passed" do
    Widget.create!(name: "Beta")

    get widgets_path(update: "widgets_list", search: "Alp"),
        headers: frame_headers("widgets_list")

    assert_response :success
    assert_includes response.body, "Alpha"
    refute_includes response.body, "Beta"
  end

  test "row show renders attribute frames" do
    frame = "widget_#{@widget.id}"
    get widget_path(@widget, update: frame), headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="#{frame}">)
    assert_includes response.body, %(<turbo-frame id="widget_#{@widget.id}_name">)
  end

  test "attribute edit renders the input in its frame" do
    frame = "widget_#{@widget.id}_name"
    get edit_widget_path(@widget, attribute: "name", form_element: "text_field",
                         update: frame),
        headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="#{frame}">)
    assert_includes response.body, %(name="name")
    assert_includes response.body, %(value="Alpha")
  end

  test "attribute update persists and renders the show state" do
    frame = "widget_#{@widget.id}_name"
    put widget_path(@widget, attribute: "name", form_element: "text_field",
                    update: frame),
        params: { name: "Renamed" }, headers: frame_headers(frame)

    assert_response :success
    assert_equal "Renamed", @widget.reload.name
    assert_includes response.body, "Renamed"
  end

  test "failed save re-renders the edit state, not a fake show (8.1.19)" do
    frame = "widget_#{@widget.id}_name"
    put widget_path(@widget, attribute: "name", form_element: "text_field",
                    update: frame),
        params: { name: "" }, headers: frame_headers(frame)

    assert_response :success
    assert_equal "Alpha", @widget.reload.name, "blank name must not persist"
    assert_includes response.body, %(name="name"),
      "expected the edit input to be re-rendered after a failed save"
    assert_includes response.body, "inline_forms_field_error"
    assert_includes response.body, "can&#39;t be blank"
  end

  test "failed save with invalid value shows validation errors in the editor" do
    frame = "widget_#{@widget.id}_notes"
    put widget_path(@widget, attribute: "notes", form_element: "plain_text_area",
                    update: frame),
        params: { notes: "short" }, headers: frame_headers(frame)

    assert_response :success
    assert_nil @widget.reload.notes
    assert_includes response.body, "inline_forms_field_error"
    assert_includes response.body, "is too short"
  end

  test "edit render shows no field error when flash is empty" do
    frame = "widget_#{@widget.id}_name"
    get edit_widget_path(@widget, attribute: "name", form_element: "text_field",
                         update: frame),
        headers: frame_headers(frame)

    assert_response :success
    refute_includes response.body, "inline_forms_field_error"
  end

  test "destroy responds with the destroyed-row state and an undo pointing at the destroy version" do
    frame = "widget_#{@widget.id}"
    assert_difference -> { Widget.count }, -1 do
      delete widget_path(@widget, update: frame), headers: frame_headers(frame)
    end
    assert_response :success

    destroy_version = PaperTrail::Version.where(item_type: "Widget",
                                                item_id: @widget.id,
                                                event: "destroy").last
    assert destroy_version, "expected a PaperTrail destroy version"
    assert_includes response.body, "/widgets/#{destroy_version.id}/revert",
      "undo link must target the destroy version (8.1.13)"
  end

  # revert responds with turbo_stream (replaces row + versions panel at once,
  # see render_revert_response); the undo/Restore links request that format.
  def turbo_stream_headers(frame_id)
    frame_headers(frame_id).merge("Accept" => "text/vnd.turbo-stream.html")
  end

  test "revert of a destroy version restores the row (undo)" do
    frame = "widget_#{@widget.id}"
    delete widget_path(@widget, update: frame), headers: frame_headers(frame)
    destroy_version = PaperTrail::Version.where(item_type: "Widget",
                                                item_id: @widget.id,
                                                event: "destroy").last

    assert_difference -> { Widget.count }, +1 do
      post revert_widget_path(destroy_version.id, update: "widgets_list"),
           headers: turbo_stream_headers("widgets_list")
    end
    assert_response :success
    assert Widget.exists?(@widget.id), "undo must restore the destroyed row"
    assert_equal "Alpha", Widget.find(@widget.id).name
  end

  test "revert of a destroy version is idempotent when the row already exists (8.1.17)" do
    frame = "widget_#{@widget.id}"
    delete widget_path(@widget, update: frame), headers: frame_headers(frame)
    destroy_version = PaperTrail::Version.where(item_type: "Widget",
                                                item_id: @widget.id,
                                                event: "destroy").last

    post revert_widget_path(destroy_version.id, update: "widgets_list"),
         headers: turbo_stream_headers("widgets_list")
    assert Widget.exists?(@widget.id)

    # Replaying the same restore must not raise RecordNotUnique.
    post revert_widget_path(destroy_version.id, update: "widgets_list"),
         headers: turbo_stream_headers("widgets_list")
    assert_response :success
    assert_equal 1, Widget.where(id: @widget.id).count
  end

  test "versions panel lists an update event" do
    @widget.update!(name: "Renamed once")
    frame = "widget_#{@widget.id}"

    get list_versions_widget_path(@widget, update: frame),
        headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, "Renamed once"
  end
end
