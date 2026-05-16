# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Stock _show partial: scalar fields are wrapped in <turbo-frame> and use HTML
# edit/update/cancel (no UJS on field links/forms). Same contract as name_list.
class ExampleAppApartmentFieldTurboTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.find_or_create_by!(name: "Turbo Field Apt") do |a|
      a.title = "Turbo Field Title"
    end
    @frame_id = "apartment_#{@apartment.id}_name"
    @turbo_headers = { "Turbo-Frame" => @frame_id }
  end

  test "show panel partial wraps scalar fields in turbo-frame" do
    get apartment_path(@apartment, update: "apartment_#{@apartment.id}"),
        headers: {
          "Accept" => "text/javascript, application/javascript",
          "X-Requested-With" => "XMLHttpRequest"
        }

    assert_response :success
    assert_includes @response.body, "turbo-frame",
      "UJS show.js.erb should embed _show with turbo-frame field wrappers"
    assert_includes @response.body, @frame_id
  end

  test "stock scalar field edit update and cancel via turbo-frame" do
    get edit_apartment_path(
      @apartment,
      attribute: "name",
      form_element: "text_field",
      update: @frame_id
    ), headers: @turbo_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame_id}">)
    refute_includes @response.body, 'data-remote="true"'

    put apartment_path(
      @apartment,
      attribute: "name",
      form_element: "text_field",
      update: @frame_id
    ), params: { name: "Stock Turbo Name" }, headers: @turbo_headers
    assert_response :success
    assert_includes @response.body, "Stock Turbo Name"
    assert_equal "Stock Turbo Name", @apartment.reload.name

    get apartment_path(
      @apartment,
      attribute: "name",
      form_element: "text_field",
      update: @frame_id
    ), headers: @turbo_headers
    assert_response :success
    assert_includes @response.body, "Stock Turbo Name"
    refute_includes @response.body, 'name="name"',
      "cancel returns read-only field, not edit form"
  end

  test "field show cancel responds to html even without Turbo-Frame header" do
    get apartment_path(
      @apartment,
      attribute: "name",
      form_element: "text_field",
      update: @frame_id
    ), headers: { "Accept" => "text/html, application/xhtml+xml" }

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame_id}">)
    assert_includes @response.body, @apartment.name
  end
end
