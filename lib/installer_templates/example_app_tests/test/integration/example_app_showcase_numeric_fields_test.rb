# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Numeric Tier 1 helpers on FormElementShowcase:
#   integer_field   (count)        + numericality validation regression
#   decimal_field   (price)
# (money_field is dropped from the showcase; the runtime helper depends on
# money-rails' `humanized_money_with_symbol`, which is not in the installer
# Gemfile. See CHANGELOG 8.1.6 "Dropped" section.)
class ExampleAppShowcaseNumericFieldsTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "Numeric demo")
    @list_frame = "form_element_showcases_list"
    @list_headers = { "Turbo-Frame" => @list_frame, "Accept" => "text/html" }
  end

  test "integer_field count round-trips" do
    frame = "form_element_showcase_#{@showcase.id}_count"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "count",
      form_element: "integer_field",
      update: frame
    ), params: { count: "42" }, headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, "42"
    assert_equal 42, @showcase.reload.count
  end

  test "decimal_field price round-trips" do
    frame = "form_element_showcase_#{@showcase.id}_price"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "price",
      form_element: "decimal_field",
      update: frame
    ), params: { price: "99.95" }, headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, "99.95"
    assert_equal "99.95", @showcase.reload.price
  end

  test "integer_field count rejects non-integer via top-level create" do
    # The controller's create iterates every attribute and calls each
    # form_element's update method. Several helpers crash on nil params:
    #   - month_year_picker_update -> Date.parse("") raises
    #   - dropdown_with_integers_update / dropdown_with_values{_with_stars}_update
    #     -> params[:_form_element_showcase][:attr] dereferences nil
    # We supply just enough to let the create walk reach the validation step.
    assert_no_difference "FormElementShowcase.count" do
      post form_element_showcases_path(update: @list_frame),
           params: {
             title: "Bad Count",
             count: "abc",
             start_month: "September 2026",
             _form_element_showcase: {
               rating_int: 1,
               priority: 1,
               priority2: 1,
               stars: 1,
             },
           },
           headers: @list_headers
    end
    assert_response :success
    body = @response.body
    assert_match(/is not a number|count[^<]*is not a number/i, body,
      "expected numericality error to render after invalid count")
  end
end
