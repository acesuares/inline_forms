# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Stock `/apartments` index: each row is `<turbo-frame id="apartment_<id>">`;
# opening/closing the inline panel uses Turbo GET `show` + `close` (HTML), not UJS.
class ExampleAppApartmentRowTurboTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.first || Apartment.create!(name: "Row Turbo Apt", title: "T")
    @row_frame = "apartment_#{@apartment.id}"
    @row_headers = { "Turbo-Frame" => @row_frame, "Accept" => "text/html" }
  end

  test "apartments index wraps each row in a turbo-frame" do
    get apartments_path
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">),
      "expected top-level list row inside turbo-frame"
  end

  test "row presentation link uses turbo navigation not UJS remote" do
    get apartments_path
    assert_response :success
    assert_select "turbo-frame##{@row_frame} div.small-11.column > a", count: 1 do |elements|
      el = elements.first
      assert_equal "true", el["data-turbo"]
      assert_equal @row_frame, el["data-turbo-frame"]
      assert_nil el["data-remote"]
    end
  end

  test "row open show returns full panel inside matching turbo-frame" do
    get apartment_path(@apartment, update: @row_frame), headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
    assert_includes @response.body, "object_presentation",
      "expected expanded _show panel"
  end

  test "row close returns collapsed row inside matching turbo-frame" do
    get apartment_path(@apartment, update: @row_frame, close: true), headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
    refute_includes @response.body, "object_presentation",
      "expected _close row, not full panel"
  end

  test "row close responds to html without Turbo-Frame header" do
    get apartment_path(
      @apartment,
      update: @row_frame,
      close: true
    ), headers: { "Accept" => "text/html, application/xhtml+xml" }

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
  end
end
