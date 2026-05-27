# frozen_string_literal: true

require "test_helper"

# Pins the FormElementShowcase model wiring:
#   - plain_text columns are present (no rich_text drift)
#   - every kept Tier 1 attribute is in the attribute list
#   - priority2 keeps its options_disabled tuple slot (8.1.5 row shape)
#   - integer numericality is enforced on :count
class ExampleAppFormElementShowcaseTest < ActiveSupport::TestCase
  EXPECTED_ATTRIBUTES = %i[
    header_basics
    title
    body_plain_area
    header_numbers
    count
    price
    header_dates
    meeting_date
    meeting_time
    birth_month
    start_month
    header_choices
    is_active
    gender
    rating_int
    priority
    priority2
    stars
    header_files
    attachment
    jingle
    cover
    header_rich
    description
    roles
    header_meta
    created_at
    updated_at
  ].freeze

  test "plain_text helper configuration validates without drift" do
    assert_nothing_raised do
      InlineForms.validate_plain_text_configuration_for!(FormElementShowcase)
    end
  end

  test "inline_forms_attribute_list contains every expected attribute" do
    keys = FormElementShowcase.new.inline_forms_attribute_list.map { |row| row.first }
    EXPECTED_ATTRIBUTES.each do |attr|
      assert_includes keys, attr, "expected #{attr} in inline_forms_attribute_list"
    end
  end

  test "priority2 keeps options_disabled at tuple slot 3 (8.1.5 row shape)" do
    row = FormElementShowcase.new.inline_forms_attribute_list.assoc(:priority2)
    assert_not_nil row, "expected a :priority2 row"
    assert_equal :dropdown_with_values, row[1]
    assert_kind_of Hash, row[2]
    assert_equal [2], row[3],
      "expected options_disabled at index 3 (was the 8.1.5 row-shape shift)"
  end

  test "count rejects non-integer input with a numericality error" do
    showcase = FormElementShowcase.new(title: "X", count: "abc")
    assert_not showcase.valid?
    assert_includes showcase.errors.attribute_names, :count
    assert showcase.errors[:count].any? { |m| m.match?(/not a number/i) },
      "expected `not a number` error on :count, got #{showcase.errors[:count].inspect}"
  end

  test "count accepts a valid integer" do
    showcase = FormElementShowcase.new(title: "X", count: 5)
    assert showcase.valid?, "expected showcase to be valid with count=5, got #{showcase.errors.full_messages.inspect}"
  end

  test "count allows blank" do
    showcase = FormElementShowcase.new(title: "X", count: nil)
    assert showcase.valid?, "expected showcase to be valid with count=nil (allow_blank), got #{showcase.errors.full_messages.inspect}"
  end
end
