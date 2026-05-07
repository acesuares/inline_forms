# frozen_string_literal: true

require_relative "test_helper"
require "rails"
require "inline_forms"

class PlainTextConfigurationTest < Minitest::Test
  class PlainTextModelWithColumn
    def self.table_exists?
      true
    end

    def self.column_names
      %w[id description]
    end

    def self.table_name
      "plain_text_model_with_columns"
    end

    def inline_forms_attribute_list
      [
        [:description, "description", :plain_text]
      ]
    end
  end

  class PlainTextModelWithoutColumn
    def self.table_exists?
      true
    end

    def self.column_names
      %w[id]
    end

    def self.table_name
      "plain_text_model_without_columns"
    end

    def inline_forms_attribute_list
      [
        [:description, "description", :plain_text]
      ]
    end
  end

  class RichTextModelWithoutColumn
    def self.table_exists?
      true
    end

    def self.column_names
      %w[id]
    end

    def inline_forms_attribute_list
      [
        [:description, "description", :rich_text]
      ]
    end
  end

  def test_plain_text_column_check_passes_when_column_exists
    model = PlainTextModelWithColumn.new
    InlineForms.assert_plain_text_column!(object: model, attribute: :description, form_element: :plain_text)
  end

  def test_plain_text_column_check_raises_when_column_missing
    model = PlainTextModelWithoutColumn.new
    error = assert_raises(InlineForms::PlainTextColumnMissingError) do
      InlineForms.assert_plain_text_column!(object: model, attribute: :description, form_element: :plain_text)
    end
    assert_includes(error.message, "has no DB column")
  end

  def test_configuration_check_raises_for_plain_text_without_column
    assert_raises(InlineForms::PlainTextColumnMissingError) do
      InlineForms.validate_plain_text_configuration_for!(PlainTextModelWithoutColumn)
    end
  end

  def test_configuration_check_allows_rich_text_without_column
    InlineForms.validate_plain_text_configuration_for!(RichTextModelWithoutColumn)
  end

  def test_text_area_alias_is_not_treated_as_plain_text_column_requirement
    refute InlineForms.plain_text_form_element?(:text_area)
  end
end
