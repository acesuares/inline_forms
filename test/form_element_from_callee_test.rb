# frozen_string_literal: true

require_relative "test_helper"

# Documents the contract between *_show helpers, +__callee__+, and
# +params[:form_element]+ (used by InlineFormsController#update as +"#{form_element}_update"+).
class FormElementFromCalleeTest < Minitest::Test
  def test_symbol_callee_typical_show_method_maps_to_controller_suffix
    got = InlineForms.form_element_string_from_callee(:text_field_show)
    assert_equal(
      "text_field",
      got,
      ":text_field_show must become the string \"text_field\" so the edit URL's " \
      "form_element matches text_field_update / text_field_edit."
    )
  end

  def test_string_callee_same_as_symbol
    got = InlineForms.form_element_string_from_callee("dropdown_with_values_show")
    assert_equal(
      "dropdown_with_values",
      got,
      "String callee from backtrace-style names must match Symbol behavior."
    )
  end

  def test_block_in_prefix_from_nested_call_still_maps_correctly
    got = InlineForms.form_element_string_from_callee("block in text_field_show")
    assert_equal(
      "text_field",
      got,
      "When *_show runs inside a block, Ruby may prefix the callee label with " \
      "\"block in \"; that prefix must be stripped before removing _show."
    )
  end

  def test_only_one_trailing_show_suffix_removed
    got = InlineForms.form_element_string_from_callee(:foo_show)
    assert_equal(
      "foo",
      got,
      "delete_suffix('_show') must remove only the trailing _show once " \
      "(not leave \"foo\" with a spurious strip)."
    )
  end

  def test_multi_word_element_name_underscores_preserved
    got = InlineForms.form_element_string_from_callee(:chicas_dropdown_with_family_members_show)
    assert_equal(
      "chicas_dropdown_with_family_members",
      got,
      "Form element names with underscores must survive unchanged except for _show."
    )
  end

  def test_callee_without_show_suffix_is_unchanged_modulo_block_prefix
    got = InlineForms.form_element_string_from_callee(:already_plain)
    assert_equal(
      "already_plain",
      got,
      "If someone passes a callee without _show, output is unchanged (minus block prefix)."
    )
  end

  def test_nil_callee_yields_empty_string
    got = InlineForms.form_element_string_from_callee(nil)
    assert_equal(
      "",
      got,
      "nil.to_s is empty; callers must pass __callee__ from a *_show method."
    )
  end
end
