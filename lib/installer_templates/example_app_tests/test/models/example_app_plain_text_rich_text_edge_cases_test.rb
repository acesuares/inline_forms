# frozen_string_literal: true

require "test_helper"

class ExampleAppPlainTextRichTextEdgeCasesTest < ActiveSupport::TestCase
  def with_temporary_inline_forms_attribute_list(klass, temporary_list)
    original = klass.instance_method(:inline_forms_attribute_list)
    klass.define_method(:inline_forms_attribute_list) { temporary_list }
    yield
  ensure
    klass.define_method(:inline_forms_attribute_list, original)
  end

  test "plain_text mapped to actiontext-backed attribute raises configuration error" do
    with_temporary_inline_forms_attribute_list(
      Apartment,
      [[:description, "description", :plain_text]]
    ) do
      error = assert_raises(InlineForms::PlainTextColumnMissingError) do
        InlineForms.validate_plain_text_configuration_for!(Apartment)
      end
      assert_includes(error.message, "description")
      assert_includes(error.message, ":rich_text")
    end
  end

  test "plain_text runtime guard raises before assigning unknown DB attribute" do
    apartment = Apartment.create!(name: "Mismatch", title: "Check")
    assert_raises(InlineForms::PlainTextColumnMissingError) do
      InlineForms.assert_plain_text_column!(
        object: apartment,
        attribute: :description,
        form_element: :plain_text
      )
    end
  end

  test "switching text column field from plain_text to rich_text does not raise" do
    with_temporary_inline_forms_attribute_list(
      Role,
      [[:description, "description", :rich_text]]
    ) do
      InlineForms.validate_plain_text_configuration_for!(Role)
    end
  end
end
