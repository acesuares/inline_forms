# frozen_string_literal: true

require_relative "test_helper"

class AttributeListTest < Minitest::Test
  def build_sample
    InlineForms::AttributeList.build do
      header :basics
      field  :name,     :text_field
      field  :priority, :dropdown_with_values, values: { 1 => "low", 2 => "high" }
      field  :flag,     :dropdown_with_values, values: { 1 => "a", 2 => "b" }, disabled: [ 2 ]
      info   :created_at, :updated_at
    end
  end

  # -- array compatibility (the whole point) -----------------------------

  def test_is_an_array
    assert_kind_of Array, build_sample
  end

  def test_destructures_like_the_legacy_literal
    seen = []
    build_sample.each { |attribute, form_element| seen << [ attribute, form_element ] }
    assert_includes seen, [ :name, :text_field ]
    assert_includes seen, [ :priority, :dropdown_with_values ]
  end

  def test_assoc_positional_values_hash_still_works
    list = build_sample
    # Consumers fetch the values hash as list.assoc(attr)[2].
    assert_equal({ 1 => "low", 2 => "high" }, list.assoc(:priority)[2])
    assert_equal([ 2 ], list.assoc(:flag)[3])
    assert_nil list.assoc(:name)[2]
  end

  def test_build_produces_expected_rows
    list = build_sample
    assert_equal(
      [
        [ :basics, :header ],
        [ :name, :text_field ],
        [ :priority, :dropdown_with_values, { 1 => "low", 2 => "high" } ],
        [ :flag, :dropdown_with_values, { 1 => "a", 2 => "b" }, [ 2 ] ],
        [ :created_at, :info ],
        [ :updated_at, :info ]
      ],
      list.to_a
    )
  end

  # -- append -------------------------------------------------------------

  def test_field_appends_and_returns_self_for_chaining
    list = InlineForms::AttributeList.new
    result = list.field(:a, :text_field).field(:b, :check_box)
    assert_same list, result
    assert_equal %i[a b], list.names
  end

  def test_disabled_without_values_raises
    assert_raises(ArgumentError) do
      InlineForms::AttributeList.new.field(:x, :dropdown_with_values, disabled: [ 1 ])
    end
  end

  # -- insertion ----------------------------------------------------------

  def test_insert_after
    list = build_sample.insert_after(:name, :nickname, :text_field)
    assert_equal :nickname, list.names[list.index_of(:name) + 1]
  end

  def test_insert_before
    list = build_sample.insert_before(:priority, :urgent, :check_box)
    assert_equal :urgent, list.names[list.index_of(:priority) - 1]
  end

  def test_insert_after_missing_anchor_raises
    assert_raises(ArgumentError) { build_sample.insert_after(:nope, :x, :text_field) }
  end

  # -- removal ------------------------------------------------------------

  def test_remove_present
    list = build_sample.remove(:priority)
    refute list.include_attribute?(:priority)
  end

  def test_remove_absent_is_noop
    list = build_sample
    before = list.dup
    list.remove(:does_not_exist)
    assert_equal before.to_a, list.to_a
  end

  # -- reordering ---------------------------------------------------------

  def test_move_after
    list = build_sample.move_after(:name, :updated_at)
    assert_equal :name, list.names.last
    assert_equal 1, list.names.count(:name)
  end

  def test_move_before
    list = build_sample.move_before(:updated_at, :basics)
    assert_equal 0, list.index_of(:updated_at)
    assert_equal 1, list.names.count(:updated_at)
  end

  def test_move_relative_to_itself_raises
    assert_raises(ArgumentError) { build_sample.move_after(:name, :name) }
  end

  # -- replacement --------------------------------------------------------

  def test_replace_element_preserves_position
    list = build_sample
    pos = list.index_of(:priority)
    list.replace_element(:priority, :radio_button, values: { 1 => "x" })
    assert_equal pos, list.index_of(:priority)
    assert_equal :radio_button, list.form_element_for(:priority)
    assert_equal({ 1 => "x" }, list.values_for(:priority))
  end

  def test_replace_element_absent_is_noop
    list = build_sample
    before = list.dup
    list.replace_element(:nope, :text_field)
    assert_equal before.to_a, list.to_a
  end

  # -- queries ------------------------------------------------------------

  def test_query_helpers
    list = build_sample
    assert_equal 1, list.index_of(:name)
    assert list.include_attribute?(:flag)
    refute list.include_attribute?(:ghost)
    assert_equal :dropdown_with_values, list.form_element_for(:priority)
    assert_equal({ 1 => "low", 2 => "high" }, list.values_for(:priority))
    assert_equal [ :name, :text_field ], list.row_for(:name)
  end

  # -- wrap ---------------------------------------------------------------

  def test_wrap_existing_array_enables_editing
    legacy = [ [ :name, :text_field ], [ :email, :text_field ] ]
    list = InlineForms::AttributeList.wrap(legacy)
    assert_kind_of InlineForms::AttributeList, list
    list.insert_after(:name, :phone, :text_field)
    assert_equal %i[name phone email], list.names
  end

  def test_wrap_is_idempotent_for_attribute_list
    list = build_sample
    assert_same list, InlineForms::AttributeList.wrap(list)
  end

  def test_module_level_builder
    list = InlineForms.attribute_list { field :a, :text_field }
    assert_kind_of InlineForms::AttributeList, list
    assert_equal %i[a], list.names
  end
end
