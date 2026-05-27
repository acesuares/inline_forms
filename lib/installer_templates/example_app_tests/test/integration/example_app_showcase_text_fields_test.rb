# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Round-trip the text-shaped Tier 1 helpers on FormElementShowcase:
#   text_field           (title)
#   plain_text_area      (body_plain_area)
class ExampleAppShowcaseTextFieldsTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "TextFields demo")
  end

  test "text_field title round-trips through the field turbo-frame" do
    frame = "form_element_showcase_#{@showcase.id}_title"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "title",
      form_element: "text_field",
      update: frame
    ), params: { title: "TextFields updated" }, headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, "TextFields updated"
    assert_equal "TextFields updated", @showcase.reload.title
  end

  test "plain_text_area body round-trips through the field turbo-frame" do
    frame = "form_element_showcase_#{@showcase.id}_body_plain_area"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    body = "Hello plain text\nMulti-line content"
    put form_element_showcase_path(
      @showcase,
      attribute: "body_plain_area",
      form_element: "plain_text_area",
      update: frame
    ), params: { body_plain_area: body }, headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, "Hello plain text"
    assert_equal body, @showcase.reload.body_plain_area
  end
end
