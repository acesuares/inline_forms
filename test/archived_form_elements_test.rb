# frozen_string_literal: true

require_relative "test_helper"
require "inline_forms/archived_form_elements"

class ArchivedFormElementsTest < Minitest::Test
  class ModelWithArchivedElement
    def inline_forms_attribute_list
      [[:address, :geo_code_curacao]]
    end
  end

  class ModelWithArchivedTree
    def inline_forms_attribute_list
      [[:children, :tree]]
    end
  end

  def test_raises_when_model_declares_archived_geo_code_curacao
    err = assert_raises(InlineForms::ArchivedFormElementError) do
      InlineForms.validate_no_archived_form_elements_for!(ModelWithArchivedElement)
    end
    assert_includes err.message, "geo_code_curacao"
    assert_includes err.message, "7.6.0"
    assert_includes err.message, "archived/form_elements/geo_code_curacao"
  end

  def test_raises_when_model_declares_archived_tree
    err = assert_raises(InlineForms::ArchivedFormElementError) do
      InlineForms.validate_no_archived_form_elements_for!(ModelWithArchivedTree)
    end
    assert_includes err.message, "tree"
    assert_includes err.message, "archived/form_elements/tree"
  end

  def test_archived_registry_documents_absence_list_without_path
    meta = InlineForms::ARCHIVED_FORM_ELEMENTS[:absence_list]
    assert_equal "6.3.0", meta[:removed_in_version]
    assert_nil meta[:archive_path]
  end
end
