# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# End-to-end coverage for `rails g inline_forms_addto Apartment
# internal_note:string`, which the installer runs during --example. Proves the
# generated column migrated, the new attribute_list row renders on the stock
# show panel, and an inline edit/update round-trips through the generic
# controller.
class ExampleAppApartmentAddtoFieldTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.find_or_create_by!(name: "Addto Field Apt") do |a|
      a.title = "Addto Field Title"
    end
    @frame_id = "apartment_#{@apartment.id}_internal_note"
    @turbo_headers = { "Turbo-Frame" => @frame_id }
  end

  test "internal_note column exists after the addto migration" do
    assert_includes Apartment.column_names, "internal_note",
      "inline_forms_addto migration should have added the internal_note column"
  end

  test "internal_note row renders on the stock show panel" do
    row_frame = "apartment_#{@apartment.id}"
    get apartment_path(@apartment, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success
    assert_includes @response.body, @frame_id,
      "the addto attribute_list row should render its own per-field turbo-frame"
  end

  test "internal_note inline edit and update round-trips" do
    get edit_apartment_path(
      @apartment,
      attribute: "internal_note",
      form_element: "text_field",
      update: @frame_id
    ), headers: @turbo_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame_id}">)

    put apartment_path(
      @apartment,
      attribute: "internal_note",
      form_element: "text_field",
      update: @frame_id
    ), params: { internal_note: "Boiler serviced 2026-07" }, headers: @turbo_headers
    assert_response :success
    assert_includes @response.body, "Boiler serviced 2026-07"
    assert_equal "Boiler serviced 2026-07", @apartment.reload.internal_note
  end
end
