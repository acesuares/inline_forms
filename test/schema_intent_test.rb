# frozen_string_literal: true

require_relative "test_helper"

class SchemaIntentTest < Minitest::Test
  def intent(**overrides)
    InlineForms::SchemaIntent.new(
      **{ model_name: "Apartment", attribute: :internal_note, form_element: :text_field }.merge(overrides)
    )
  end

  def test_normalizes_types
    i = intent(attribute: "note", form_element: "text_field", after: "name")
    assert_equal "Apartment", i.model_name
    assert_equal :note, i.attribute
    assert_equal :text_field, i.form_element
    assert_equal :name, i.after
    assert_equal :draft, i.status
  end

  def test_column_token
    assert_equal "internal_note:text_field", intent.column_token
  end

  def test_generator_args_plain
    assert_equal [ "Apartment", "internal_note:text_field" ], intent.generator_args
  end

  def test_generator_args_with_after
    assert_equal [ "Apartment", "internal_note:text_field", "--after=name" ],
                 intent(after: :name).generator_args
  end

  def test_generator_args_with_before
    assert_equal [ "Apartment", "internal_note:text_field", "--before=created_at" ],
                 intent(before: :created_at).generator_args
  end

  def test_status_validation
    assert_raises(ArgumentError) { intent(status: :bogus) }
    i = intent
    i.status = :applied
    assert_equal :applied, i.status
  end

  def test_to_h_round_trips_core_fields
    h = intent(after: :name, values: { 1 => "a" }).to_h
    assert_equal "Apartment", h[:model_name]
    assert_equal :internal_note, h[:attribute]
    assert_equal({ 1 => "a" }, h[:values])
    assert_equal :name, h[:after]
  end
end
