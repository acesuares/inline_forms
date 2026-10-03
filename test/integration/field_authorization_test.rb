# frozen_string_literal: true

require_relative "../integration_test_helper"

# Server-side guard on the single-field actions (edit / update / show with an
# attribute). The UI only hides the edit link for an attribute the user may
# not update; before 8.1.48 a hand-made request still went through, because
# load_and_authorize_resource authorizes the record only (CanCanCan passes
# attribute-scoped rules when no attribute is given) and `form_element` was
# dispatched as `send("#{form_element}_update")` unchecked.
class FieldAuthorizationTest < InlineFormsIntegrationTestCase
  setup do
    @widget = Widget.create!(name: "Alpha", accent: "#112233")
    @frame = "widget_#{@widget.id}_accent"
  end

  def patch_field(attribute, form_element, params = {})
    patch widget_path(@widget, attribute: attribute, form_element: form_element,
                               update: "widget_#{@widget.id}_#{attribute}"),
          params: params, headers: frame_headers("widget_#{@widget.id}_#{attribute}")
  end

  test "the dummy runs with CanCanCan enabled" do
    assert InlineFormsController.cancan_enabled?
  end

  test "crafted PATCH on an attribute-scoped `cannot :update` is refused" do
    Ability.restrictions = -> { cannot :update, Widget, [ :accent ] }

    patch_field "accent", "color_field", accent: "#ff0000"

    assert_response :forbidden
    assert_equal "#112233", @widget.reload.accent
  end

  test "other attributes of the same record stay updatable" do
    Ability.restrictions = -> { cannot :update, Widget, [ :accent ] }

    patch_field "name", "text_field", name: "Renamed"

    assert_response :success
    assert_equal "Renamed", @widget.reload.name
  end

  test "an attribute-scoped `can :update` only covers the listed attributes" do
    Ability.restrictions = lambda do
      cannot :update, Widget
      can :update, Widget, [ :name ]
    end

    patch_field "accent", "color_field", accent: "#ff0000"
    assert_response :forbidden
    assert_equal "#112233", @widget.reload.accent

    patch_field "name", "text_field", name: "Renamed"
    assert_response :success
    assert_equal "Renamed", @widget.reload.name
  end

  test "edit of a `cannot :update` attribute is refused" do
    Ability.restrictions = -> { cannot :update, Widget, [ :accent ] }

    get edit_widget_path(@widget, attribute: "accent", form_element: "color_field", update: @frame),
        headers: frame_headers(@frame)

    assert_response :forbidden
  end

  test "single-field show of a `cannot :read` attribute is refused" do
    Ability.restrictions = -> { cannot :read, Widget, [ :accent ] }

    get widget_path(@widget, attribute: "accent", form_element: "color_field", update: @frame),
        headers: frame_headers(@frame)

    assert_response :forbidden
  end

  test "a form_element that does not match the attribute's row is rejected" do
    patch_field "accent", "text_field", accent: "not a color"

    assert_response :bad_request
    assert_equal "#112233", @widget.reload.accent
  end

  test "an unknown form_element is rejected before it is dispatched" do
    patch_field "name", "nonexistent", name: "Renamed"

    assert_response :bad_request
    assert_equal "Alpha", @widget.reload.name
  end

  test "an attribute outside the attribute list is rejected" do
    patch_field "kind_id", "text_field", kind_id: "42"

    assert_response :bad_request
    assert_nil @widget.reload.kind_id
  end

  test "missing attribute or form_element is rejected" do
    patch widget_path(@widget, update: @frame), params: { name: "x" }, headers: frame_headers(@frame)
    assert_response :bad_request

    get edit_widget_path(@widget, attribute: "name", update: @frame), headers: frame_headers(@frame)
    assert_response :bad_request
  end

  test "show cannot be used to send an arbitrary method to the record" do
    get widget_path(@widget, attribute: "destroy", form_element: "has_one", update: @frame),
        headers: frame_headers(@frame)

    assert_response :bad_request
    assert Widget.exists?(@widget.id)
  end

  test "a delegating element's link name (plain_text_area -> plain_text) is accepted" do
    patch_field "notes", "plain_text", notes: "Long enough notes"

    assert_response :success
    assert_equal "Long enough notes", @widget.reload.notes
  end

  test "attribute_list_row_for honours the declared element and its delegate only" do
    list = Widget.new.inline_forms_attribute_list

    assert_equal [ :notes, :plain_text_area ], InlineForms.attribute_list_row_for(list, "notes", "plain_text_area")
    assert_equal [ :notes, :plain_text_area ], InlineForms.attribute_list_row_for(list, "notes", "plain_text")
    assert_nil InlineForms.attribute_list_row_for(list, "notes", "rich_text")
    assert_nil InlineForms.attribute_list_row_for(list, "name", nil)
    assert_nil InlineForms.attribute_list_row_for(list, nil, "text_field")
  end
end
