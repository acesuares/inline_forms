# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Example app includes opening_date:date on Apartment (jQuery UI datepicker).
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

  test "inline edit opening_date uses datepicker class hook" do
    get edit_apartment_path(
      @apartment,
      attribute: "opening_date",
      form_element: "date_select",
      update: @frame_id
    ), headers: @turbo_headers

    assert_response :success
    assert_includes @response.body, %(class="datepicker")
    assert_includes @response.body, %(name="opening_date")
    refute_includes @response.body, "<script",
      "datepicker init is centralized in inline_forms.js"
  end

  test "new apartment form includes datepicker for opening_date" do
    get new_apartment_path(update: @list_frame), headers: @list_headers

    assert_response :success
    assert_includes @response.body, %(name="opening_date")
    assert_includes @response.body, %(class="datepicker")
  end
end
