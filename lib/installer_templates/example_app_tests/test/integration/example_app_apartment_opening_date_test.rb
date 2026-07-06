# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Example app includes opening_date:date on Apartment (native date input since 8.1.25).
class ExampleAppApartmentOpeningDateTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.find_or_create_by!(name: "Datepicker Apt") do |a|
      a.title = "Has an opening date"
      a.opening_date = Date.new(2019, 3, 15)
    end
    @frame_id = "apartment_#{@apartment.id}_opening_date"
    @turbo_headers = { "Turbo-Frame" => @frame_id, "Accept" => "text/html" }
    @list_frame = "apartments_list"
    @list_headers = { "Turbo-Frame" => @list_frame, "Accept" => "text/html" }
  end

  test "show panel displays opening_date" do
    row_frame = "apartment_#{@apartment.id}"
    get apartment_path(@apartment, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success
    assert_includes @response.body, "15-03-2019"
  end

  test "inline edit opening_date renders a native date input" do
    get edit_apartment_path(
      @apartment,
      attribute: "opening_date",
      form_element: "date_select",
      update: @frame_id
    ), headers: @turbo_headers

    assert_response :success
    assert_includes @response.body, %(type="date")
    assert_includes @response.body, %(name="opening_date")
    assert_includes @response.body, %(value="2019-03-15"), "value must be ISO 8601"
    refute_includes @response.body, "<script",
      "native inputs need no per-field init script"
  end

  test "new apartment form includes a native date input for opening_date" do
    get new_apartment_path(update: @list_frame), headers: @list_headers

    assert_response :success
    assert_includes @response.body, %(name="opening_date")
    assert_includes @response.body, %(type="date")
  end
end
