# frozen_string_literal: true

require_relative "../integration_test_helper"

# Model data that a helper concatenates into a string it marks html_safe must
# be escaped first. info_list_show did `out << item._presentation`, so a
# _presentation built from user input (StProject: User#name listed on a Role)
# ran as markup on every page that showed the list (stored XSS). Same audit:
# file_field_show (stored file name / url) and the rich-text changeset in the
# versions list (was `raw`).
class PresentationEscapingTest < InlineFormsIntegrationTestCase
  MARKUP = "<img src=x onerror=alert(1)>"
  ESCAPED = "&lt;img src=x onerror=alert(1)&gt;"

  # A view context of a real request: helpers, can?, url helpers.
  def view
    @view ||= begin
      get widgets_path
      controller.view_context
    end
  end

  test "info_list escapes each item's _presentation" do
    machine = Machine.create!(name: "Press")
    Part.create!(name: MARKUP, machine: machine)
    Part.create!(name: "Gear", machine: machine)

    html = view.info_list_show(machine, :parts)

    refute_includes html, "<img"
    assert_includes html, ESCAPED
    assert_includes html, "Gear"
    assert_includes html, "<div class='row", "the row markup itself is kept"
  end

  test "file_field escapes the stored file name and url" do
    widget = Widget.create!(name: "Manual")
    stored = Struct.new(:url, :path) do
      def present? = true
      def to_s = url
    end.new(%(/uploads/x'><img src=x onerror=alert(1)>.pdf), %(/uploads/#{MARKUP}.pdf))
    widget.define_singleton_method(:manual) { stored }

    html = view.file_field_show(widget, :manual)

    refute_includes html, "<img"
    assert_includes html, ESCAPED
  end

  test "dropdown_with_other and the list rows escape _presentation" do
    kind = Kind.create!(name: MARKUP)
    widget = Widget.create!(name: MARKUP, kind: kind)

    refute_includes view.dropdown_with_other_show(widget, :kind), "<img"

    get widgets_path(update: "widgets_list"), headers: frame_headers("widgets_list")
    assert_response :success
    refute_includes response.body, "<img"
    assert_includes response.body, ESCAPED
  end

  test "a rich-text changeset in the versions list is sanitized, not raw" do
    machine = Machine.create!(name: "Press")
    version = Struct.new(:id, :event, :changeset, :created_at, :whodunnit) do
      def to_param = id.to_s
    end.new(1, "update", { "body" => [ "<p>old</p><script>alert(1)</script>", "<p>new</p>#{MARKUP}" ] }, Time.current, nil)
    context = view
    context.instance_variable_set(:@object, machine)
    context.define_singleton_method(:inline_forms_history_for) do |_object|
      [ { version: version, kind: :rich_text, rich_text_name: "description", at: version.created_at } ]
    end

    html = context.render(partial: "inline_forms/versions_list")

    refute_includes html, "<script"
    refute_includes html, "onerror"
    assert_includes html, "<p>old</p>"
    assert_includes html, "<p>new</p>"
  end
end
