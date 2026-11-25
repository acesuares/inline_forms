# frozen_string_literal: true

require_relative "../integration_test_helper"

# The review of 8.1.81-8.1.84 (8.1.85): the rich_text delegate past an app's
# own text_area_update, a vendored element saved through the controller, the
# boot check after the app's to_prepare, a mixed values list, and the tests
# the review found missing.
class ReviewFixes8185Test < InlineFormsIntegrationTestCase
  def with_row(row)
    WidgetsController.define_method(:review_row) { @inline_forms_attribute_list = [ row ] }
    WidgetsController.before_action :review_row
    yield
  ensure
    WidgetsController.skip_before_action :review_row, raise: false
    WidgetsController.remove_method(:review_row) if WidgetsController.method_defined?(:review_row, false)
  end

  # ---- 1. any of the app's text_area helpers keeps the rich_text delegate away

  test "an app's own text_area_update alone refuses form_element=rich_text" do
    widget = Widget.create!(name: "Alpha", notes: "<p>stored text</p>")
    frame = "widget_#{widget.id}_notes"
    app_update = Module.new { def text_area_update(object, attribute) = object.send("#{attribute}=", "app checked") }
    InlineFormsController.include(app_update)

    with_row([ :notes, :text_area ]) do
      patch widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
            params: { notes: "<p>raw</p>" }, headers: frame_headers(frame)
      assert_response :bad_request
      assert_equal "<p>stored text</p>", widget.reload.notes

      patch widget_path(widget, attribute: "notes", form_element: "text_area", update: frame),
            params: { notes: "<p>raw</p>" }, headers: frame_headers(frame)
      assert_response :success
      assert_equal "app checked", widget.reload.notes
    end
  ensure
    app_update.send(:remove_method, :text_area_update)
  end

  test "an app's own text_area_edit alone refuses form_element=rich_text" do
    widget = Widget.create!(name: "Alpha", notes: "<p>stored text</p>")
    frame = "widget_#{widget.id}_notes"
    app_edit = Module.new { def text_area_edit(*) = "app's own edit" }
    InlineFormsHelper.include(app_edit)

    with_row([ :notes, :text_area ]) do
      get edit_widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
          headers: frame_headers(frame)
      assert_response :bad_request
    end
  ensure
    app_edit.send(:remove_method, :text_area_edit)
  end

  # ---- 2. a vendored element: _update reaches the controller ---------------

  test "a vendored element included into the helper and the controller shows, edits and saves" do
    widget = Widget.create!(name: "Alpha")
    frame = "widget_#{widget.id}_name"
    vendored = Module.new do
      private

      def geo_code_curacao_show(object, attribute) = "geo: #{object.send(attribute)}"
      def geo_code_curacao_edit(object, attribute) = text_field_tag(attribute, object.send(attribute))
      def geo_code_curacao_update(object, attribute) = object.send("#{attribute}=", "#{params[attribute]} (geo)")
    end
    [ InlineFormsHelper, InlineFormsController ].each { |target| target.include(vendored) }

    with_row([ :name, :geo_code_curacao ]) do
      get edit_widget_path(widget, attribute: "name", form_element: "geo_code_curacao", update: frame),
          headers: frame_headers(frame)
      assert_response :success

      patch widget_path(widget, attribute: "name", form_element: "geo_code_curacao", update: frame),
            params: { name: "Punda" }, headers: frame_headers(frame)
      assert_response :success
      assert_equal "Punda (geo)", widget.reload.name
      assert_includes response.body, "geo: Punda (geo)"
    end
  ensure
    %i[geo_code_curacao_show geo_code_curacao_edit geo_code_curacao_update].each do |name|
      vendored.send(:remove_method, name)
    end
  end

  # ---- 5. the boot check runs after the app's own to_prepare blocks ---------

  test "the loaded-model check is a prepare callback after the app's own" do
    files = Rails.application.reloader.__callbacks[:prepare].map do |callback|
      callback.filter.respond_to?(:source_location) ? callback.filter.source_location&.first.to_s : ""
    end
    engine = files.rindex { |file| file.end_with?("lib/inline_forms.rb") }
    app = files.rindex { |file| file.include?("test/dummy/config/initializers/") }

    assert engine, "inline_forms registers its model check as a prepare callback"
    assert app, "the dummy app registers a prepare block of its own"
    assert_operator engine, :>, app
  end

  test "validate_loaded_models! refuses an archived element nobody vendored" do
    archived = Class.new do
      def self.name = "ArchivedWidget"
      def inline_forms_attribute_list = [ [ :name, :tree ] ]
    end
    raise "descendants is already ActiveRecord::Base's own" if ActiveRecord::Base.singleton_methods(false).include?(:descendants)

    ActiveRecord::Base.define_singleton_method(:descendants) { [ archived ] }

    assert_raises(InlineForms::ArchivedFormElementError) { InlineForms.validate_loaded_models! }
  ensure
    ActiveRecord::Base.singleton_class.remove_method(:descendants) if ActiveRecord::Base.singleton_methods(false).include?(:descendants)
  end

  # ---- 3. a values list of numbers and strings --------------------------------

  test "a values list that mixes numbers and strings sorts without raising" do
    helpers = ApplicationController.helpers
    helpers.instance_variable_set(:@inline_forms_attribute_list, [ [ :priority, :dropdown_with_values, [ 2, "many", 1, nil ] ] ])

    values = helpers.send(:attribute_values, Widget.new, :priority)
    assert_equal [ [ 3, nil ], [ 2, 1 ], [ 0, 2 ], [ 1, "many" ] ], values

    helpers.instance_variable_set(:@inline_forms_attribute_list, [ [ :hours, :dropdown_with_values, 0..12 ] ])
    assert_equal (0..12).to_a, helpers.send(:attribute_values, Widget.new, :hours).map(&:last)
  end

  # ---- 6. tests the review found missing ----------------------------------------

  test "the engine header's logout link is a Turbo DELETE" do
    get widgets_path
    assert_response :success
    assert_select %(a[data-turbo-method="delete"][href="#{destroy_user_session_path}"])
  end

  test "an update override written `super and return` stops after the engine refused" do
    widget = Widget.create!(name: "Alpha")
    WidgetsController.define_method(:update) do
      super() and return if params[:form_element]

      render plain: "the app's own"
    end
    frame = "widget_#{widget.id}_name"

    patch widget_path(widget, attribute: "name", form_element: "no_such_element", update: frame),
          headers: frame_headers(frame)
    assert_response :bad_request

    patch widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
          params: { name: "Renamed" }, headers: frame_headers(frame)
    assert_response :success
    assert_equal "Renamed", widget.reload.name
  ensure
    WidgetsController.remove_method(:update) if WidgetsController.method_defined?(:update, false)
  end

  test "a field show and a save on a model without an instance attribute list name the model" do
    widget = Widget.create!(name: "Alpha")
    Widget.alias_method :__saved_list, :inline_forms_attribute_list
    Widget.remove_method :inline_forms_attribute_list
    frame = "widget_#{widget.id}_name"

    error = assert_raises(InlineForms::MissingAttributeListError) do
      get widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
          headers: frame_headers(frame)
    end
    assert_includes error.message, "Widget has no instance method"

    assert_raises(InlineForms::MissingAttributeListError) do
      patch widget_path(widget, attribute: "name", form_element: "text_field", update: frame),
            params: { name: "Renamed" }, headers: frame_headers(frame)
    end
  ensure
    Widget.alias_method :inline_forms_attribute_list, :__saved_list
    Widget.remove_method :__saved_list
  end
end
