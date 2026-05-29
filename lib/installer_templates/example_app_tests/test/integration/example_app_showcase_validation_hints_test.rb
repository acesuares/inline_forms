# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Regression for the 8.1.20 validation-hint fixes on FormElementShowcase:
#
#   * count  (integer_field, `numericality: { only_integer: true }`)
#   * price  (decimal_field, bare `numericality: true`)
#   * amount (money_field,  money-rails `monetize :amount_cents`, which
#             registers a MoneyValidator on `:amount`)
#
# Before 8.1.20 a bare `numericality: true` emitted ZERO hint messages
# (validation_hints dead-code bug), so `price` rendered an EMPTY
# `validation-hints-source` div, and `amount` had no i18n mapping for the
# money validator key. The show panel must now render a NON-EMPTY
# `<ul class="validation-hints-list">` for all three.
class ExampleAppShowcaseValidationHintsTest < ExampleAppIntegrationTestCase
  setup do
    @full = FormElementShowcase.find_or_create_by!(title: "Hints demo") do |s|
      s.count  = 7
      s.price  = "12.34"
      s.amount = Money.from_amount(99.95, "USD") if s.respond_to?(:amount=) && defined?(Money)
    end
    @row_frame = "form_element_showcase_#{@full.id}"
    @row_headers = { "Turbo-Frame" => @row_frame, "Accept" => "text/html" }
  end

  test "count label renders a non-empty validation-hints list" do
    body = show_panel_body
    assert_nonempty_hint(body, :count, "must be a number", "must be an integer")
  end

  test "price label renders a non-empty validation-hints list (bare numericality: true)" do
    body = show_panel_body
    assert_nonempty_hint(body, :price, "must be a number")
  end

  test "amount label renders a non-empty validation-hints list (money-rails validator)" do
    skip "money-rails monetize not configured" unless FormElementShowcase.respond_to?(:monetized_attributes) &&
      FormElementShowcase.monetized_attributes.key?("amount")

    body = show_panel_body
    assert_nonempty_hint(body, :amount, "must be a valid amount")
  end

  private

  def show_panel_body
    get form_element_showcase_path(@full, update: @row_frame), headers: @row_headers
    assert_response :success
    @response.body
  end

  # Asserts the hidden `validation-hints-source` div for +attribute+ exists
  # AND contains a populated `<ul class="validation-hints-list">` with each
  # expected message fragment — i.e. not the empty source div the pre-8.1.20
  # bug produced.
  def assert_nonempty_hint(body, attribute, *expected_messages)
    hint_id = "validation_hints_form_element_showcase_#{@full.id}_#{attribute}"

    assert_includes body, %(data-validation-hints-source="#{hint_id}"),
      "expected has-tip trigger wired to #{hint_id}"

    source = body[
      %r{<div id="#{Regexp.escape(hint_id)}" class="validation-hints-source" hidden>(.*?)</div>}m,
      1
    ]
    refute_nil source, "expected a validation-hints-source div for #{attribute}"
    assert_includes source, '<ul class="validation-hints-list">',
      "expected a NON-EMPTY hints list for #{attribute}, got source: #{source.inspect}"

    expected_messages.each do |message|
      assert_includes source, message,
        "expected #{attribute} hint list to include #{message.inspect}"
    end
  end
end
