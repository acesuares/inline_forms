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

  test "date_select meeting_date renders native date input on edit" do
    @showcase.update!(meeting_date: Date.new(2026, 5, 17))
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
    assert_includes @response.body, %(type="date")
    assert_includes @response.body, %(name="meeting_date")
    assert_includes @response.body, %(value="2026-05-17"), "value must be ISO 8601"
    refute_includes @response.body, "<script", "no inline picker init"
  end

  test "time_select meeting_time renders native time input on edit" do
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
    assert_includes @response.body, %(type="time")
    assert_includes @response.body, %(name="meeting_time")
    assert_includes @response.body, %(value="09:15"), "value must be 24h HH:MM"
  end

  test "time_select round-trips a native HH:MM submission" do
    @showcase.update!(meeting_time: Time.utc(2000, 1, 1, 9, 15))
    frame = "form_element_showcase_#{@showcase.id}_meeting_time"

    put form_element_showcase_path(
      @showcase,
      attribute: "meeting_time",
      form_element: "time_select",
      update: frame
    ), params: { meeting_time: "14:30" },
       headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    @showcase.reload
    assert_equal 14, @showcase.meeting_time.hour
    assert_equal 30, @showcase.meeting_time.min
  end

  test "date_select round-trips a native ISO submission" do
    frame = "form_element_showcase_#{@showcase.id}_meeting_date"

    put form_element_showcase_path(
      @showcase,
      attribute: "meeting_date",
      form_element: "date_select",
      update: frame
    ), params: { meeting_date: "2027-01-09" },
       headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    assert_equal Date.new(2027, 1, 9), @showcase.reload.meeting_date
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

  test "month_year_picker start_month renders native month input on edit" do
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
    assert_includes @response.body, %(type="month")
    assert_includes @response.body, %(name="start_month")
    assert_includes @response.body, %(value="2026-05"), "value must be ISO YYYY-MM"
  end

  test "month_year_picker round-trips native YYYY-MM and legacy 'Month YYYY' submissions" do
    frame = "form_element_showcase_#{@showcase.id}_start_month"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    # Native <input type="month"> value.
    put form_element_showcase_path(
      @showcase,
      attribute: "start_month",
      form_element: "month_year_picker",
      update: frame
    ), params: { start_month: "2026-09" }, headers: headers
    assert_response :success
    assert_equal Date.new(2026, 9, 1), @showcase.reload.start_month

    # Legacy pre-8.1.25 display format still parses via the fallback.
    put form_element_showcase_path(
      @showcase,
      attribute: "start_month",
      form_element: "month_year_picker",
      update: frame
    ), params: { start_month: "November 2027" }, headers: headers
    assert_response :success
    assert_equal Date.new(2027, 11, 1), @showcase.reload.start_month
  end
end
