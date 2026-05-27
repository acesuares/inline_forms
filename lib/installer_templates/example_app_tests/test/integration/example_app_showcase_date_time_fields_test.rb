# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Date/time-shaped Tier 1 helpers on FormElementShowcase:
#   date_select       (meeting_date)
#   time_select       (meeting_time)
#   month_select      (birth_month, 1..12 integer)
#   month_year_picker (start_month, date)
class ExampleAppShowcaseDateTimeFieldsTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "Date/time demo")
  end

  test "date_select meeting_date renders datepicker on edit" do
    frame = "form_element_showcase_#{@showcase.id}_meeting_date"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    get edit_form_element_showcase_path(
      @showcase,
      attribute: "meeting_date",
      form_element: "date_select",
      update: frame
    ), headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, %(class="datepicker")
    assert_includes @response.body, %(name="meeting_date")
  end

  test "time_select meeting_time renders timepicker on edit" do
    @showcase.update!(meeting_time: Time.utc(2000, 1, 1, 9, 15))
    frame = "form_element_showcase_#{@showcase.id}_meeting_time"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    get edit_form_element_showcase_path(
      @showcase,
      attribute: "meeting_time",
      form_element: "time_select",
      update: frame
    ), headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, %(class="timepicker")
    assert_includes @response.body, %(name="meeting_time")
  end

  test "month_select birth_month renders 12 options on edit" do
    @showcase.update!(birth_month: 6)
    frame = "form_element_showcase_#{@showcase.id}_birth_month"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    get edit_form_element_showcase_path(
      @showcase,
      attribute: "birth_month",
      form_element: "month_select",
      update: frame
    ), headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_match(/<select[^>]+name="date\[birth_month\]"/, @response.body)
  end

  test "month_year_picker start_month renders datepicker class hook" do
    @showcase.update!(start_month: Date.new(2026, 5, 1))
    frame = "form_element_showcase_#{@showcase.id}_start_month"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    get edit_form_element_showcase_path(
      @showcase,
      attribute: "start_month",
      form_element: "month_year_picker",
      update: frame
    ), headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, %(datepicker-month-year)
    assert_includes @response.body, %(name="start_month")
  end
end
