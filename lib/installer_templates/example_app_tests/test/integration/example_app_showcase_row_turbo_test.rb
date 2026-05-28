# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# FormElementShowcase uses the stock InlineFormsController destroy/revert path.
class ExampleAppShowcaseRowTurboTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "Row turbo demo") { |s| s.count = 1 }
    @row_frame = "form_element_showcase_#{@showcase.id}"
    @row_headers = { "Turbo-Frame" => @row_frame, "Accept" => "text/html" }
  end

  test "destroy via Turbo DELETE returns undo inside matching turbo-frame" do
    delete form_element_showcase_path(@showcase, update: @row_frame), headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
    assert_includes @response.body, "undo"
    assert_not FormElementShowcase.exists?(@showcase.id)
  end

  test "revert via Turbo POST after destroy restores row without CanCan authorization error" do
    showcase_id = @showcase.id
    delete form_element_showcase_path(@showcase, update: @row_frame), headers: @row_headers
    assert_response :success

    destroy_version = PaperTrail::Version.where(
      item_type: "FormElementShowcase",
      item_id: showcase_id,
      event: "destroy"
    ).order(:id).last
    assert destroy_version, "expected a destroy PaperTrail version"

    post revert_form_element_showcase_path(destroy_version, update: @row_frame),
         headers: {
           "Turbo-Frame" => @row_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert FormElementShowcase.where(id: showcase_id, title: "Row turbo demo").exists?
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{@row_frame}")
  end

  test "destroy undo restores plain text area edited on Empty demo" do
    empty = FormElementShowcase.find_or_create_by!(title: "Empty demo")
    body = "Plain text survives undo"
    field_frame = "form_element_showcase_#{empty.id}_body_plain_area"
    put form_element_showcase_path(
      empty,
      attribute: "body_plain_area",
      form_element: "plain_text_area",
      update: field_frame
    ), params: { body_plain_area: body },
       headers: { "Turbo-Frame" => field_frame, "Accept" => "text/html" }
    assert_response :success
    assert_equal body, empty.reload.body_plain_area

    empty_id = empty.id
    row_frame = "form_element_showcase_#{empty_id}"
    delete form_element_showcase_path(empty, update: row_frame), headers: @row_headers
    assert_response :success
    assert_includes @response.body, "undo"

    undo_version_id = @response.body[/revert\/(\d+)/, 1]
    assert undo_version_id, "undo link should target a PaperTrail version id"
    destroy_version = PaperTrail::Version.find(undo_version_id)
    assert_equal "destroy", destroy_version.event,
      "undo must target the destroy version, not the last update"

    post revert_form_element_showcase_path(destroy_version, update: row_frame),
         headers: {
           "Turbo-Frame" => row_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_equal body, FormElementShowcase.find(empty_id).body_plain_area

    get form_element_showcase_path(empty_id, update: row_frame),
        headers: @row_headers
    assert_includes @response.body, body
  end
end
