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
    amount
    latitude
    longitude
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
    scale_int
    scale_val
    header_files
    attachment
    jingle
    cover
    header_rich
    description
    locales
    locales_display
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

  # ---------------------------------------------------------------------
  # 8.1.10: :decimal_field now maps to a real :decimal column with
  # precision/scale instead of the legacy varchar. The migration emitter
  # applies (10, 2) by default and reads `{p,s}` overrides from the CLI
  # type suffix (e.g. `latitude:decimal_field{9,6}` -> decimal(9,6)).
  # ---------------------------------------------------------------------

  test "decimal_field maps to a real :decimal column with default precision/scale" do
    price_col = FormElementShowcase.columns_hash["price"]
    assert_not_nil price_col, "expected a :price column"
    assert_equal :decimal, price_col.type,
      "expected :price to be a :decimal column, got #{price_col.type.inspect} (#{price_col.sql_type.inspect})"
    assert_equal 10, price_col.precision, "expected default precision: 10"
    assert_equal  2, price_col.scale,     "expected default scale: 2"
  end

  test "decimal_field{p,s} CLI suffix sets precision and scale" do
    lat = FormElementShowcase.columns_hash["latitude"]
    lon = FormElementShowcase.columns_hash["longitude"]
    assert_equal :decimal, lat.type
    assert_equal :decimal, lon.type
    assert_equal [9, 6],  [lat.precision, lat.scale],
      "expected latitude:decimal_field{9,6} -> decimal(9,6), got decimal(#{lat.precision},#{lat.scale})"
    assert_equal [10, 6], [lon.precision, lon.scale],
      "expected longitude:decimal_field{10,6} -> decimal(10,6), got decimal(#{lon.precision},#{lon.scale})"
  end

  test "decimal column round-trips BigDecimal losslessly at full scale" do
    showcase = FormElementShowcase.create!(
      title: "decimal-roundtrip",
      latitude:  BigDecimal("12.123456"),
      longitude: BigDecimal("-68.987654"),
    )
    showcase.reload
    assert_kind_of BigDecimal, showcase.latitude
    assert_equal BigDecimal("12.123456"),  showcase.latitude
    assert_equal BigDecimal("-68.987654"), showcase.longitude
  end

  test "price rejects non-numeric input with a numericality error" do
    showcase = FormElementShowcase.new(title: "X", price: "ace")
    assert_not showcase.valid?
    assert_includes showcase.errors.attribute_names, :price
    assert showcase.errors[:price].any? { |m| m.match?(/not a number/i) },
      "expected `not a number` error on :price, got #{showcase.errors[:price].inspect}"
  end

  test "latitude rejects out-of-range values via numericality range" do
    showcase = FormElementShowcase.new(title: "X", latitude: 91)
    assert_not showcase.valid?
    assert_includes showcase.errors.attribute_names, :latitude
  end

  test "longitude rejects out-of-range values via numericality range" do
    showcase = FormElementShowcase.new(title: "X", longitude: 181)
    assert_not showcase.valid?
    assert_includes showcase.errors.attribute_names, :longitude
  end
end
