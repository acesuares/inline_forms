# frozen_string_literal: true

require_relative "../integration_test_helper"

# The fourth ladder note (8.1.88): a notice for a refused file, the plus rule
# for markup without text, and a primary-key tiebreaker in order: :relation.
class LadderFixesFourTest < InlineFormsIntegrationTestCase
  ROOT = File.expand_path("../..", __dir__)

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

  def notes_frame(widget, action)
    frame = "widget_#{widget.id}_notes"
    path = action == :edit ? edit_widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame) :
                             widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame)
    with_notes_as(:rich_text) { get path, headers: frame_headers(frame) }
    assert_response :success
    response.body
  end

  # ---- 1. a refused file gives a message ----------------------------------------

  test "a plain-column editor carries the translated refusal message" do
    widget = Widget.create!(name: "Alpha", notes: "<p>stored text</p>")
    notes_frame(widget, :edit)

    assert_select "trix-editor.inline_forms-trix-no-files[data-no-files-message=?]",
                  I18n.t("inline_forms.files.not_in_this_field", locale: :en)
    assert_equal "Files cannot be added to this field.", I18n.t("inline_forms.files.not_in_this_field", locale: :en)
    assert_predicate I18n.t("inline_forms.files.not_in_this_field", locale: :nl, raise: true), :present?
  end

  test "the refusal shows the message under the editor and a change takes it away" do
    js = File.read(File.join(ROOT, "app/assets/javascripts/inline_forms/inline_forms.js"))
    accept = js[/document\.addEventListener\("trix-file-accept".*?\n  \}\);/m]
    change = js[/document\.addEventListener\("trix-change".*?\n  \}\);/m]

    assert accept, "inline_forms.js listens for trix-file-accept"
    assert_includes accept, "event.preventDefault()"
    assert_includes accept, %(getAttribute("data-no-files-message"))
    assert_includes accept, %(insertAdjacentElement("afterend", notice))
    assert_includes accept, "notice.textContent = message"
    assert change, "inline_forms.js listens for trix-change"
    assert_includes change, %(classList.contains("inline_forms-trix-refused"))
    assert_includes change, "notice.remove()"
  end

  # ---- 2. markup without text gets the plus -------------------------------------

  test "a lone <hr> or a table of empty cells shows the plus" do
    [ "<hr>", "<table><tr><td></td><td>&nbsp;</td></tr></table>" ].each do |stored|
      widget = Widget.create!(name: "Alpha")
      widget.update_column(:notes, stored)

      assert_includes notes_frame(widget, :show), "fi-plus", "#{stored} shows the plus"
    end
  end

  # ---- 3. order: :relation pages in one fixed order -----------------------------

  test "order: :relation orders by the primary key after the value" do
    Member.create!(name: "Ada")
    sql = []
    log = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?("LIMIT") && payload[:name] != "SCHEMA" }

    ActiveSupport::Notifications.subscribed(log, "sql.active_record") do
      InlineForms::Suggestions.values(Member.order(created_at: :desc), :name, "ad", order: :relation)
    end

    assert_equal 1, sql.size
    assert_match(/ORDER BY "members"\."created_at" DESC, LOWER\("members"\."name"\) ASC, "members"\."id" ASC/, sql.first)
  end

  test "rows equal on the order and the value are read once each across pages" do
    now = Time.current
    names = Array.new(60) { |i| i.even? ? "Ada" : "ada" } + [ "Adam" ]
    Member.insert_all(names.map { |name| { name: name, created_at: now, updated_at: now } })
    read = []
    log = ->(*, payload) { read << payload[:sql] if payload[:sql].include?("OFFSET") && payload[:name] != "SCHEMA" }

    found = ActiveSupport::Notifications.subscribed(log, "sql.active_record") do
      InlineForms::Suggestions.values(Member.order(created_at: :desc), :name, "ad", order: :relation, limit: 2)
    end

    assert_equal %w[Ada Adam], found
    assert_operator read.size, :>=, 1, "the 61 rows take more than one page of 8"
  end
end
