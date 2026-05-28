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
end
