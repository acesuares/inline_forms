# frozen_string_literal: true

require_relative "../integration_test_helper"

# The second ladder prompt (8.1.84): a private vendored helper, field requests
# for rows that are not fields, a model without an instance attribute list,
# show's return value, a :rich_text value on a plain column, the info
# element's DateTime, and the versions header after a save.
class LadderFixesTwoTest < InlineFormsIntegrationTestCase
  # ---- 1. a vendored element's helpers may be private -------------------------

  test "a private <element>_show counts as a vendored archived element" do
    helpers = Module.new do
      private

      def geo_code_curacao_show(*) = "app's own"
    end
    view = Object.new.extend(helpers)

    assert InlineForms.vendored_form_element?(:geo_code_curacao, view)
    refute InlineForms.vendored_form_element?(:tree, view)
  end

  # ---- 2. a listed row that is not a field --------------------------------------

  test "a listed :associated row requested as a field is refused with 400, not a 500" do
    machine = Machine.create!(name: "M1")
    frame = "machine_#{machine.id}_parts"

    get machine_path(machine, attribute: "parts", form_element: "associated", update: frame),
        headers: frame_headers(frame)
    assert_response :bad_request

    get edit_machine_path(machine, attribute: "parts", form_element: "associated", update: frame),
        headers: frame_headers(frame)
    assert_response :bad_request

    patch machine_path(machine, attribute: "parts", form_element: "associated", update: frame),
          headers: frame_headers(frame)
    assert_response :bad_request
  end

  # ---- 3. no instance attribute list ------------------------------------------

  test "a field request on a model without an instance attribute list names the model" do
    widget = Widget.create!(name: "Alpha")
    Widget.alias_method :__saved_list, :inline_forms_attribute_list
    Widget.remove_method :inline_forms_attribute_list
    frame = "widget_#{widget.id}_name"

    error = assert_raises(InlineForms::MissingAttributeListError) do
      get edit_widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
          headers: frame_headers(frame)
    end
    assert_includes error.message, "Widget has no instance method inline_forms_attribute_list"
  ensure
    Widget.alias_method :inline_forms_attribute_list, :__saved_list
    Widget.remove_method :__saved_list
  end

  # ---- 4. show answers true, a refusal too -------------------------------------

  test "an override written `super and return` stops after the engine refused" do
    widget = Widget.create!(name: "Alpha")
    WidgetsController.define_method(:show) do
      super() and return if params[:form_element]

      render plain: "the app's own"
    end
    frame = "widget_#{widget.id}_name"

    get widget_path(widget, attribute: "name", form_element: "no_such_element", update: frame),
        headers: frame_headers(frame)
    assert_response :bad_request

    get widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
        headers: frame_headers(frame)
    assert_response :success
    assert_includes response.body, "Alpha"
  ensure
    WidgetsController.remove_method(:show) if WidgetsController.method_defined?(:show, false)
  end

  # ---- 5 and 8. :rich_text on a plain column ----------------------------------

  # Widget#notes is a plain text column; these tests list it as :rich_text
  # (or :text_area) for the request.
  def with_notes_as(form_element)
    WidgetsController.define_method(:notes_list) do
      @inline_forms_attribute_list = [ [ :notes, form_element ] ]
    end
    WidgetsController.before_action :notes_list
    yield
  ensure
    WidgetsController.skip_before_action :notes_list, raise: false
    WidgetsController.remove_method(:notes_list) if WidgetsController.method_defined?(:notes_list, false)
  end

  test "a plain column's HTML under :rich_text is shown through the allowlist" do
    stored = <<~HTML
      <script>alert(1)</script><p onclick="alert(2)">Kept <u>underlined</u></p>
      <img src=x onerror="alert(3)"><a href="javascript:alert(4)">link</a>
      <table border="1"><tr><td style="color: red; background: url(x)">cell</td></tr></table>
    HTML
    widget = Widget.create!(name: "Alpha", notes: stored)
    frame = "widget_#{widget.id}_notes"

    with_notes_as(:rich_text) do
      get widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
          headers: frame_headers(frame)
    end

    assert_response :success
    html = response.body
    refute_includes html, "<script>alert"
    refute_includes html, "onclick"
    refute_includes html, "onerror"
    refute_includes html, "<img"
    refute_includes html, "javascript:"
    refute_includes html, "url("
    assert_includes html, "<u>underlined</u>"
    assert_includes html, %(<table border="1">)
    assert_includes html, %(style="color:red;")
  end

  test "rich_text_edit on a plain column marks the editor so the attach button is hidden" do
    widget = Widget.create!(name: "Alpha", notes: "<p>stored text</p>")
    frame = "widget_#{widget.id}_notes"

    with_notes_as(:rich_text) do
      get edit_widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
          headers: frame_headers(frame)
    end

    assert_response :success
    assert_select "trix-editor.inline_forms-trix-no-files"
  end

  test "form_element=rich_text on a :text_area row is refused when the app has its own text_area" do
    widget = Widget.create!(name: "Alpha", notes: "<p>stored text</p>")
    frame = "widget_#{widget.id}_notes"

    with_notes_as(:text_area) do
      get widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
          headers: frame_headers(frame)
      assert_response :success, "the engine's own text_area delegates to rich_text"

      app_text_area = Module.new { def text_area_show(*) = "app's own" }
      InlineFormsHelper.include(app_text_area)
      begin
        get widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
            headers: frame_headers(frame)
        assert_response :bad_request

        get widget_path(widget, attribute: "notes", form_element: "text_area", update: frame),
            headers: frame_headers(frame)
        assert_response :success
        assert_includes response.body, "app&#39;s own"
      ensure
        app_text_area.send(:remove_method, :text_area_show)
      end
    end
  end

  # ---- 7 and 11. the info element formats a DateTime --------------------------

  test "info formats a DateTime and a Time like the versions panel, a Date as dd-mm-yyyy" do
    helpers = ApplicationController.helpers
    widget = Widget.new(released_on: Date.new(2026, 11, 24))
    at = DateTime.new(2026, 11, 24, 22, 13, 13)
    widget.define_singleton_method(:stamp) { at }

    text = helpers.info_show(widget, :stamp)
    refute_includes text, "2026-11-24"
    assert_match(/\A24 Nov 2026 22:13 \(/, text)
    assert_equal "24-11-2026", helpers.info_info(widget, :released_on)
  end

  # ---- 12. the versions header after a field save ------------------------------

  test "a field save also replaces the record's versions header with the new count" do
    widget = Widget.create!(name: "Alpha")
    frame = "widget_#{widget.id}_name"
    versions_frame = ApplicationController.helpers.inline_forms_versions_turbo_frame_id(widget)

    patch widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
          params: { name: "Renamed" }, headers: frame_headers(frame)

    assert_response :success
    assert_select %(turbo-frame##{frame} turbo-stream[action=replace][target="#{versions_frame}"])
    assert_includes response.body, I18n.t("inline_forms.view.versions", count: widget.versions.count)
  end

  test "a field's plain show (cancel) does not touch the versions panel" do
    widget = Widget.create!(name: "Alpha")
    frame = "widget_#{widget.id}_name"

    get widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
        headers: frame_headers(frame)

    assert_select "turbo-stream", count: 0
  end
end
