# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Numeric Tier 1 helpers on FormElementShowcase:
#   integer_field   (count)        + numericality validation regression
#   decimal_field   (price)
#   money_field     (amount, money-rails `monetize :amount_cents`)
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

  test "money_field amount round-trips through monetize :amount_cents" do
    skip "money-rails monetize not configured" unless FormElementShowcase.respond_to?(:monetized_attributes) &&
      FormElementShowcase.monetized_attributes.key?("amount")

    frame = "form_element_showcase_#{@showcase.id}_amount"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "amount",
      form_element: "money_field",
      update: frame
    ), params: { amount: "12.34" }, headers: headers

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    reloaded = @showcase.reload
    assert_equal 1234, reloaded.amount_cents,
      "expected monetize to parse '12.34' into 1234 cents, got #{reloaded.amount_cents.inspect}"
  end

  test "integer_field count rejects non-integer via top-level create" do
    # The controller's create iterates every attribute and calls each
    # form_element's update method. Several helpers used to crash on nil
    # params (month_year_picker_update, scale_*_update, dropdown_*_update)
    # so we supply just enough to let the create walk reach validation.
    assert_no_difference "FormElementShowcase.count" do
      post form_element_showcases_path(update: @list_frame),
           params: {
             title: "Bad Count",
             count: "abc",
             amount: "0.00",
             start_month: "September 2026",
             _form_element_showcase: {
               rating_int: 1,
               priority: 1,
               priority2: 1,
               stars: 1,
               scale_int: 1,
               scale_val: 1,
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
