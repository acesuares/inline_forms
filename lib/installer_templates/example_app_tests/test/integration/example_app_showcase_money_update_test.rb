# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Regression for the inline attribute :update action.
#
# The bug: `update` ignored the return value of `@object.save` and always
# re-rendered `field_show` from the in-memory `@object`. money-rails rejects
# an unparseable amount like "99.ace99" (the monetized validator fails, so
# `save` returns false and `amount_cents` is never written), yet the user saw
# a "saved" show of the unsaved in-memory value. Re-opening the edit revealed
# the old value -- the success render was a lie.
#
# The fix branches on `@object.save`: on failure it re-renders the EDIT field
# (with the rejected raw input still visible) instead of a fake show.
class ExampleAppShowcaseMoneyUpdateTest < ExampleAppIntegrationTestCase
  setup do
    skip "money-rails monetize not configured" unless FormElementShowcase.respond_to?(:monetized_attributes) &&
      FormElementShowcase.monetized_attributes.key?("amount")

    # Mirror the seeded "Full demo" showcase ($99.95 == 9995 cents).
    @showcase = FormElementShowcase.find_or_create_by!(title: "Full demo")
    @showcase.update!(amount: Money.from_amount(99.95, "USD"))
    assert_equal 9995, @showcase.reload.amount_cents

    @frame = "form_element_showcase_#{@showcase.id}_amount"
    @headers = { "Turbo-Frame" => @frame, "Accept" => "text/html" }
  end

  test "malformed money update does not persist and re-renders the edit field, not a fake show" do
    put form_element_showcase_path(
      @showcase,
      attribute: "amount",
      form_element: "money_field",
      update: @frame
    ), params: { amount: "99.ace99" }, headers: @headers

    assert_response :success

    # The DB value is untouched -- no silent mutation, no bad write.
    assert_equal 9995, @showcase.reload.amount_cents,
      "malformed '99.ace99' must not persist; amount_cents should stay 9995"
    assert_equal Money.from_amount(99.95, "USD"), @showcase.reload.amount

    body = @response.body

    # The response is the EDIT state (text field), not a turbo field_show.
    assert_includes body, %(<turbo-frame id="#{@frame}">)
    assert_includes body, "input_money_field",
      "expected the edit text field (input_money_field) to be re-rendered"
    # The rejected raw input stays visible so the user can correct it.
    assert_includes body, "99.ace99",
      "expected the rejected raw input to remain in the edit field"

    # It must NOT present a saved show of the in-memory 99.99 value.
    refute_match(/\$\s*99\.99/, body,
      "response must not present a fake '$99.99' saved show after a failed save")
  end

  test "valid money update persists and renders the show" do
    put form_element_showcase_path(
      @showcase,
      attribute: "amount",
      form_element: "money_field",
      update: @frame
    ), params: { amount: "12.34" }, headers: @headers

    assert_response :success
    assert_equal 1234, @showcase.reload.amount_cents,
      "valid '12.34' must persist as 1234 cents"
    assert_includes @response.body, %(<turbo-frame id="#{@frame}">)
    assert_includes @response.body, "12.34"
    # Show state renders the humanized money, not the edit text field.
    refute_includes @response.body, "input_money_field",
      "valid update should render the show, not the edit field"
  end
end
