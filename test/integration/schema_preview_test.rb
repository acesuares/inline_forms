# frozen_string_literal: true

require_relative "../integration_test_helper"

# Cheap preview of a SchemaIntent against the dummy app: a virtual typed
# attribute on a throwaway subclass + an AttributeList with the proposed row
# spliced in — no migration, no column, real class/table untouched.
class SchemaPreviewTest < InlineFormsIntegrationTestCase
  def scalar_intent(**overrides)
    InlineForms::SchemaIntent.new(
      **{ model_name: "Widget", attribute: :internal_note, form_element: :text_field }.merge(overrides)
    )
  end

  test "supported? is true for scalar elements, false for relations/uploaders/virtuals" do
    assert InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :text_field))
    assert InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :integer_field))
    assert InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :date_select))
    assert InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :check_box))
    refute InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :dropdown))
    refute InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :rich_text))
    refute InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :image_field))
    refute InlineForms::SchemaPreview.supported?(scalar_intent(form_element: :money_field))
  end

  test "preview object carries the proposed attribute as a virtual, no column" do
    object, = InlineForms::SchemaPreview.build(scalar_intent)

    assert object.respond_to?(:internal_note), "preview should expose the virtual attribute"
    assert_nil object.internal_note, "virtual attribute defaults to nil with no column"
    object.internal_note = "boiler serviced"
    assert_equal "boiler serviced", object.internal_note, "virtual attribute is writable in memory"

    # The real class/table are untouched.
    refute_includes Widget.column_names, "internal_note"
    assert_equal "Widget", object.class.name, "preview masquerades as the base class"
  end

  test "preview attribute_list splices the row at --after" do
    _, list = InlineForms::SchemaPreview.build(scalar_intent(after: :name))
    assert_kind_of InlineForms::AttributeList, list
    assert_equal :internal_note, list.names[list.index_of(:name) + 1]
    # original rows are preserved
    assert list.include_attribute?(:priority)
  end

  test "preview attribute_list appends when no anchor given" do
    _, list = InlineForms::SchemaPreview.build(scalar_intent)
    assert_equal :internal_note, list.names.last
  end

  test "preview seeds existing attributes from a base record" do
    widget = Widget.create!(name: "Base", priority: 2)
    object, = InlineForms::SchemaPreview.build(scalar_intent, widget)
    assert_equal "Base", object.name, "existing data is carried into the preview"
    assert_nil object.internal_note
  end

  test "building a preview does not add a column to the real table" do
    before = Widget.column_names.dup
    InlineForms::SchemaPreview.build(scalar_intent(after: :name))
    Widget.reset_column_information
    assert_equal before, Widget.column_names
  end
end
