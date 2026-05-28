# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Numeric Tier 1 helpers on FormElementShowcase:
#   integer_field   (count)                  + numericality validation regression
#   decimal_field   (price)                  default precision: 10, scale: 2
#   decimal_field   (latitude, longitude)    explicit `{p,s}` CLI suffix:
#                                            decimal(9,6) / decimal(10,6)
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

  test "decimal_field price round-trips as BigDecimal with default precision/scale" do
    # Since 8.1.10 the registry maps :decimal_field to a real :decimal
    # column. Bare `price:decimal_field` (no `{p,s}` suffix) defaults to
    # precision: 10, scale: 2 — so 99.95 round-trips losslessly *and*
    # ActiveRecord returns a BigDecimal, not a String.
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
    reloaded_price = @showcase.reload.price
    assert_kind_of BigDecimal, reloaded_price,
      "expected :decimal column to return BigDecimal, got #{reloaded_price.class}"
    assert_equal BigDecimal("99.95"), reloaded_price
  end

  test "decimal_field{9,6} latitude round-trips at full scale (6 fractional digits)" do
    # The `latitude:decimal_field{9,6}` CLI suffix should give us
    # exactly 6 fractional digits of precision — enough for ~11cm
    # accuracy in GPS terms. Pick a value that fully populates the
    # scale so we'd catch off-by-one truncation.
    frame = "form_element_showcase_#{@showcase.id}_latitude"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "latitude",
      form_element: "decimal_field",
      update: frame
    ), params: { latitude: "12.123456" }, headers: headers

    assert_response :success
    reloaded = @showcase.reload.latitude
    assert_kind_of BigDecimal, reloaded
    assert_equal BigDecimal("12.123456"), reloaded
  end

  test "decimal_field{10,6} longitude accepts the full ±180 range" do
    frame = "form_element_showcase_#{@showcase.id}_longitude"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    put form_element_showcase_path(
      @showcase,
      attribute: "longitude",
      form_element: "decimal_field",
      update: frame
    ), params: { longitude: "-179.999999" }, headers: headers

    assert_response :success
    assert_equal BigDecimal("-179.999999"), @showcase.reload.longitude
  end

  test "decimal_field price rejects non-numeric via top-level create" do
    # Counterpart to the integer_field rejection test below. Without
    # the `validates :price, numericality: true` line in the showcase
    # model, ActiveRecord would silently cast "ace" to BigDecimal("0")
    # and the create would succeed. The validation keeps the
    # round-trip honest.
    assert_no_difference "FormElementShowcase.count" do
      post form_element_showcases_path(update: @list_frame),
           params: {
             title: "Bad Price",
             price: "ace",
             count: 1,
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
    assert_match(/is not a number|price[^<]*is not a number/i, @response.body,
      "expected numericality error to render after invalid price")
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
