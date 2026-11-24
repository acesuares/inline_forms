# frozen_string_literal: true

require_relative "../integration_test_helper"
require "minitest/mock"

# Fixes from the RACVS / yavetracker Rails ladder (8.1.81): an app's own list
# filter survives index, dates read dd-mm-yyyy, new and create in a Turbo
# frame answer without the full layout, the cancel is a link (no <input>
# inside an <a>), top-level page links advance the address bar, and Trix
# loads once, in <head>.
class LadderFixesTest < InlineFormsIntegrationTestCase
  SCRIPT_BUNDLE = %r{<script[^>]+inline_forms/inline_forms[^"]*\.js}

  # ---- 5. an app's filtered @objects -----------------------------------------

  test "an @objects the app set before index keeps its filter, narrowed by the ability" do
    %w[Alpha Beta Bravo].each { |name| Widget.create!(name: name) }
    WidgetsController.define_method(:only_b_widgets) { @objects = Widget.where("name LIKE ?", "B%") }
    WidgetsController.before_action :only_b_widgets, only: :index
    Ability.restrictions = -> { cannot :read, Widget, name: "Bravo" }

    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_response :success
    assert_includes response.body, "Beta"
    refute_includes response.body, "Alpha", "the app's filter is kept"
    refute_includes response.body, "Bravo", "the ability still narrows it"
  ensure
    WidgetsController.skip_before_action :only_b_widgets, raise: false
    WidgetsController.remove_method(:only_b_widgets) if WidgetsController.method_defined?(:only_b_widgets, false) || WidgetsController.private_method_defined?(:only_b_widgets, false)
  end

  test "the app's filter on the ability's own column is kept too" do
    %w[Alpha Beta Bravo].each { |name| Widget.create!(name: name) }
    # `merge` would let the ability's name IN (Beta, Bravo) replace the app's name = Beta.
    WidgetsController.define_method(:only_beta) { @objects = Widget.where(name: "Beta") }
    WidgetsController.before_action :only_beta, only: :index
    Ability.restrictions = -> { cannot :read, Widget; can :read, Widget, name: %w[Beta Bravo] }

    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_response :success
    assert_includes response.body, "Beta"
    refute_includes response.body, "Bravo", "the app's filter is kept"
    refute_includes response.body, "Alpha"
  ensure
    WidgetsController.skip_before_action :only_beta, raise: false
    WidgetsController.remove_method(:only_beta) if WidgetsController.method_defined?(:only_beta, false)
  end

  test "an app filter with its own order or joins is narrowed by the ability too" do
    %w[Alpha Beta Bravo].each { |name| Widget.create!(name: name) }
    WidgetsController.define_method(:b_widgets_ordered) { @objects = Widget.where("widgets.name LIKE ?", "B%").order(name: :desc).left_joins(:kind) }
    WidgetsController.before_action :b_widgets_ordered, only: :index
    Ability.restrictions = -> { cannot :read, Widget, name: "Bravo" }

    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_includes response.body, "Beta"
    refute_includes response.body, "Bravo"
    refute_includes response.body, "Alpha"
  ensure
    WidgetsController.skip_before_action :b_widgets_ordered, raise: false
    WidgetsController.remove_method(:b_widgets_ordered) if WidgetsController.method_defined?(:b_widgets_ordered, false)
  end

  test "without an @objects of the app's, index lists what the ability allows" do
    %w[Alpha Beta].each { |name| Widget.create!(name: name) }
    Ability.restrictions = -> { cannot :read, Widget, name: "Beta" }

    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_includes response.body, "Alpha"
    refute_includes response.body, "Beta"
  end

  # ---- 6. dates ----------------------------------------------------------------

  test "a date reads dd-mm-yyyy in the field, as info and in the versions panel" do
    widget = Widget.create!(name: "Dated", released_on: Date.new(2026, 1, 13))
    widget.update!(released_on: Date.new(2026, 2, 14))
    helpers = ApplicationController.helpers

    assert_equal "13-01-2026", helpers.date_select_info(Widget.new(released_on: Date.new(2026, 1, 13)), :released_on)
    assert_equal "-", helpers.date_select_info(Widget.new, :released_on)
    assert_equal "13-01-2026", helpers.info_show(Widget.new(released_on: Date.new(2026, 1, 13)), :released_on)
    assert_equal "13-01-2026", helpers.send(:inline_forms_value_text, Date.new(2026, 1, 13))
    assert_equal "plain", helpers.send(:inline_forms_value_text, "plain")
    assert_nil helpers.send(:inline_forms_value_text, nil)

    frame = "widget_#{widget.id}"
    get list_versions_widget_path(widget, update: frame), headers: frame_headers(frame)

    assert_includes response.body, "13-01-2026"
    assert_includes response.body, "14-02-2026"
    refute_includes response.body, "2026-01-13"
  end

  # ---- 9. new and create in a Turbo frame --------------------------------------

  test "new in a Turbo frame answers the frame without the full layout" do
    get new_widget_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="widgets_list")
    assert_no_match SCRIPT_BUNDLE, response.body
  end

  test "a successful create in a Turbo frame answers the frame without the full layout" do
    post gizmos_path(update: "gizmos_list"), params: { name: "Created" }, headers: frame_headers("gizmos_list")

    assert_response :success
    assert_includes response.body, "Created"
    assert_no_match SCRIPT_BUNDLE, response.body
  end

  test "a full page load of the list keeps the layout" do
    get widgets_path

    assert_match SCRIPT_BUNDLE, response.body
  end

  # ---- 10. the cancel is a link ------------------------------------------------

  test "the field cancel and the new form's cancel are links, with no input inside" do
    widget = Widget.create!(name: "Alpha")
    frame = "widget_#{widget.id}_name"
    get edit_widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
        headers: frame_headers(frame)

    assert_select "a.inline_forms-field-cancel.postfix.button.alert[role=button]", text: "cancel"
    assert_select "a input", count: 0

    get new_widget_path(update: "widgets_list"), headers: frame_headers("widgets_list")

    assert_select "a.inline_forms-new-cancel.button.alert[role=button]", text: "cancel"
    assert_select "a input", count: 0
  end

  # ---- 12b. page links advance the address bar ---------------------------------

  test "a top-level list's page links advance the address bar" do
    35.times { |i| Widget.create!(name: format("W%02d", i)) }

    get widgets_path

    assert_select "a[href*='page=2'][data-turbo-action=advance]"
  end

  # ---- 7. Trix ----------------------------------------------------------------

  test "Trix loads once, in head" do
    get widgets_path

    head, body = response.body.split("</head>", 2)
    assert_match %r{<script[^>]+trix[^"]*\.js}, head
    assert_no_match %r{<script[^>]+trix[^"]*\.js}, body
  end

  # ---- 13. form-element helpers are not actions --------------------------------

  test "the form-element helpers are not actions of an inline_forms controller" do
    helpers = WidgetsController.action_methods.grep(/_(show|edit|update|info)\z/)

    assert_empty helpers, "form-element helpers counted as actions: #{helpers.first(5).join(", ")}"
    assert WidgetsController.private_method_defined?(:text_field_update)
    assert_includes WidgetsController.action_methods, "update"
  end

  # ---- 14. Restore without an object_changes column --------------------------

  test "without an object_changes column every update keeps its Restore link" do
    widget = Widget.create!(name: "Versioned")
    widget.update!(name: "Renamed")
    version = widget.versions.last
    helpers = ApplicationController.helpers

    refute helpers.send(:inline_forms_empty_changeset?, version), "a real change"
    version.define_singleton_method(:changeset) { {} }
    assert helpers.send(:inline_forms_empty_changeset?, version), "an empty update, with the column"

    columns = PaperTrail::Version.column_names - [ "object_changes" ]
    PaperTrail::Version.stub(:column_names, columns) do
      refute helpers.send(:inline_forms_empty_changeset?, version), "no column: Restore stays"
    end
  end

  # ---- 15. a value without a translation -------------------------------------

  test "a dropdown value without a translation reads as itself, in show and in edit" do
    widget = Widget.create!(name: "Untranslated", priority: 2)
    frame = "widget_#{widget.id}_priority"

    get widget_path(widget, update: frame), headers: frame_headers("widget_#{widget.id}")
    refute_includes response.body, "translation_missing"
    refute_includes response.body, "&lt;span"

    get edit_widget_path(widget, attribute: "priority", form_element: "dropdown_with_values", update: frame),
        headers: frame_headers(frame)
    assert_select "option[value=2]", text: "mid"
    refute_includes response.body, "translation_missing"
  end
end
