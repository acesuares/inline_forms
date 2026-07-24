# frozen_string_literal: true

require_relative "../integration_test_helper"

# First-ever render coverage for two legacy display elements that no example
# app exercises (see stuff/improvement-plan.md §4): simple_file_field (raw
# filename column + host-provided download route) and pdf_link (host-provided
# /:attribute/:id report route).
class LegacyElementsTest < InlineFormsIntegrationTestCase
  setup do
    @widget = Widget.create!(name: "Legacy")
  end

  test "simple_file_field blank state renders the inline-edit plus link" do
    frame = "widget_#{@widget.id}"
    get widget_path(@widget, update: frame), headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="widget_#{@widget.id}_manual">)
    assert_includes response.body, "fi-plus"
  end

  test "simple_file_field present state download link bypasses Turbo" do
    @widget.update!(manual: "Lida.png")
    frame = "widget_#{@widget.id}"
    get widget_path(@widget, update: frame), headers: frame_headers(frame)

    assert_response :success
    # The download link must carry data-turbo="false" so the browser handles
    # the send_data response natively instead of Turbo loading the binary into
    # the frame (a no-op). The route method comes from the values entry.
    assert_match %r{<a[^>]*data-turbo="false"[^>]*href="/widgets/download/#{@widget.id}"}, response.body
  end

  test "simple_file_field edit renders a file input" do
    frame = "widget_#{@widget.id}_manual"
    get edit_widget_path(@widget, attribute: "manual",
                         form_element: "simple_file_field", update: frame),
        headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, %(type="file")
    assert_includes response.body, %(name="manual")
  end

  test "pdf_link show renders preview and pdf links for the attribute route" do
    frame = "widget_#{@widget.id}"
    get widget_path(@widget, update: frame), headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, %(href="/report/#{@widget.id}")
    assert_includes response.body, %(href="/report/#{@widget.id}.pdf")
  end
end
