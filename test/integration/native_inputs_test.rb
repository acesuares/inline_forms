# frozen_string_literal: true

require_relative "../integration_test_helper"

# Engine-level render coverage for the native-input form elements introduced
# in 8.1.25/8.1.26 (previously only covered by the example-app gate).
class NativeInputsTest < InlineFormsIntegrationTestCase
  setup do
    @widget = Widget.create!(
      name: "Native",
      released_on: Date.new(2026, 5, 17),
      meeting_at: Time.utc(2000, 1, 1, 9, 15),
      start_month: Date.new(2026, 5, 1),
      priority: 2,
      rating: 3
    )
  end

  def edit_attribute(attribute, form_element)
    frame = "widget_#{@widget.id}_#{attribute}"
    get edit_widget_path(@widget, attribute: attribute, form_element: form_element,
                         update: frame),
        headers: frame_headers(frame)
    assert_response :success
    response.body
  end

  test "date_select renders a native date input with ISO value" do
    body = edit_attribute("released_on", "date_select")
    assert_includes body, %(type="date")
    assert_includes body, %(value="2026-05-17")
    refute_includes body, "<script"
  end

  test "time_select renders a native time input with HH:MM value" do
    body = edit_attribute("meeting_at", "time_select")
    assert_includes body, %(type="time")
    assert_includes body, %(value="09:15")
  end

  test "month_year_picker renders a native month input with YYYY-MM value" do
    body = edit_attribute("start_month", "month_year_picker")
    assert_includes body, %(type="month")
    assert_includes body, %(value="2026-05")
  end

  test "month_year_picker update accepts native and legacy formats" do
    frame = "widget_#{@widget.id}_start_month"

    put widget_path(@widget, attribute: "start_month",
                    form_element: "month_year_picker", update: frame),
        params: { start_month: "2026-09" }, headers: frame_headers(frame)
    assert_equal Date.new(2026, 9, 1), @widget.reload.start_month

    put widget_path(@widget, attribute: "start_month",
                    form_element: "month_year_picker", update: frame),
        params: { start_month: "November 2027" }, headers: frame_headers(frame)
    assert_equal Date.new(2027, 11, 1), @widget.reload.start_month
  end

  test "dropdown_with_other renders a datalist-backed combobox without inline scripts" do
    Kind.create!(name: "Gadget")
    Kind.create!(name: "Gizmo")

    body = edit_attribute("kind", "dropdown_with_other")
    assert_includes body, "<datalist"
    assert_includes body, %(<option value="Gadget">)
    assert_includes body, %(<option value="Gizmo">)
    assert_includes body, %(name="_widget[kind_other]")
    refute_includes body, "<script"
  end

  test "dropdown_with_other update matches an existing record by name" do
    kind = Kind.create!(name: "Gadget")
    frame = "widget_#{@widget.id}_kind"

    put widget_path(@widget, attribute: "kind",
                    form_element: "dropdown_with_other", update: frame),
        params: { _widget: { kind_other: "Gadget" } }, headers: frame_headers(frame)

    assert_response :success
    @widget.reload
    assert_equal kind.id, @widget.kind_id
    assert_nil @widget.kind_other
  end

  test "dropdown_with_other update stores unmatched text as the other value" do
    Kind.create!(name: "Gadget")
    frame = "widget_#{@widget.id}_kind"

    put widget_path(@widget, attribute: "kind",
                    form_element: "dropdown_with_other", update: frame),
        params: { _widget: { kind_other: "Completely new thing" } },
        headers: frame_headers(frame)

    assert_response :success
    @widget.reload
    assert_equal 0, @widget.kind_id
    assert_equal "Completely new thing", @widget.kind_other
  end

  test "slider_with_values renders a native range input with label data" do
    body = edit_attribute("rating", "slider_with_values")
    assert_includes body, %(type="range")
    assert_includes body, "slider_with_values"
    assert_includes body, "data-slider-values"
    assert_includes body, %(<output)
    refute_includes body, "<script"
  end

  test "slider_with_values show renders a progress bar (clickable, non-interactive)" do
    frame = "widget_#{@widget.id}"
    get widget_path(@widget, update: frame), headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, "<progress"
  end

  test "color_field renders a native color input and round-trips a hex value" do
    @widget.update!(accent: "#a3381e")
    body = edit_attribute("accent", "color_field")
    assert_includes body, %(type="color")
    assert_includes body, %(value="#a3381e")

    frame = "widget_#{@widget.id}_accent"
    put widget_path(@widget, attribute: "accent", form_element: "color_field",
                    update: frame),
        params: { accent: "#2563EB" }, headers: frame_headers(frame)
    assert_response :success
    assert_equal "#2563eb", @widget.reload.accent, "hex is normalized to lowercase"

    # Junk input is rejected server-side (stored as nil), not persisted raw.
    put widget_path(@widget, attribute: "accent", form_element: "color_field",
                    update: frame),
        params: { accent: "red; background:url(x)" }, headers: frame_headers(frame)
    assert_nil @widget.reload.accent
  end
end
