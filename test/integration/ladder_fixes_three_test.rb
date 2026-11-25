# frozen_string_literal: true

require_relative "../integration_test_helper"

# The third ladder prompt (8.1.86): <font> in the display allowlist, the plus
# for a value the allowlist empties, suggestions in the relation's order and
# from a named scope, and the field request check by the calling action.
class LadderFixesThreeTest < InlineFormsIntegrationTestCase
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

  def show_notes(widget)
    frame = "widget_#{widget.id}_notes"
    with_notes_as(:rich_text) do
      get widget_path(widget, attribute: "notes", form_element: "rich_text", update: frame),
          headers: frame_headers(frame)
    end
    assert_response :success
    response.body
  end

  # ---- 1. CKEditor's <font> ----------------------------------------------------

  test "a plain column's <font> keeps its color, face and size" do
    html = InlineForms.rich_text_display_html(
      %(<font color="#ff0000" face="Arial" size="2" onmouseover="x()">x</font> <kbd>k</kbd><tt>t</tt><var>v</var><samp>s</samp>)
    )

    assert_includes html, %(<font color="#ff0000" face="Arial" size="2">x</font>)
    refute_includes html, "onmouseover"
    assert_equal "<p>kept</p>", InlineForms.rich_text_display_html("<script>alert(1)</script><style>p{}</style><p>kept</p>").to_s
    %w[kbd tt var samp].each { |tag| assert_includes html, "<#{tag}>" }
  end

  test "the display sanitizer is built once" do
    assert_same InlineForms.rich_text_display_sanitizer, InlineForms.rich_text_display_sanitizer
  end

  # ---- 2. a value the allowlist empties --------------------------------------

  test "a plain column holding only what the allowlist drops shows the plus" do
    [ %(<img src="x">), "<p></p>", "<script>alert(1)</script>", "<p>&nbsp;</p>" ].each do |stored|
      widget = Widget.create!(name: "Alpha")
      widget.update_column(:notes, stored) # past the notes length validation
      html = show_notes(widget)

      assert_includes html, "fi-plus", "#{stored} shows the plus"
    end
  end

  test "a plain column with text shows the text, no plus" do
    widget = Widget.create!(name: "Alpha", notes: "<p>Some notes here</p>")
    html = show_notes(widget)

    assert_includes html, "Some notes here"
    refute_includes html, "fi-plus"
  end

  # ---- 4. suggestions in the relation's order, from a named scope -----------

  test "order: :relation keeps the relation's order, each value once" do
    %w[Anna Bart Carla anna].each_with_index { |name, i| Member.create!(name: name, created_at: i.days.ago) }
    oldest_first = Member.order(created_at: :asc)

    assert_equal %w[Anna Bart Carla], InlineForms::Suggestions.values(oldest_first, :name, "a")
    assert_equal %w[anna Carla Bart], InlineForms::Suggestions.values(oldest_first, :name, "a", order: :relation)
    assert_equal %w[anna Carla], InlineForms::Suggestions.values(oldest_first, :name, "a", order: :relation, limit: 2)
  end

  test "order: :relation without an order of its own is A-Z" do
    %w[Carla Bart Anna].each { |name| Member.create!(name: name) }

    assert_equal %w[Anna Bart Carla], InlineForms::Suggestions.values(Member.all, :name, "a", order: :relation)
  end

  test "order: :relation finds enough values past many repeats" do
    50.times { Member.create!(name: "Ada") }
    Member.create!(name: "Adam")

    assert_equal %w[Ada Adam], InlineForms::Suggestions.values(Member.all, :name, "ad", order: :relation, limit: 2)
  end

  test "an unknown order is refused when the macro is declared" do
    assert_raises(ArgumentError) { InlineForms::Suggestions.check_order!(:newest) }
    assert_raises(ArgumentError) do
      Class.new(InlineFormsController) { suggest_names :member, :name, order: :newest }
    end
    assert_raises(ArgumentError) do
      Class.new(InlineFormsController) { suggest_names :member, :name, scope: "recent" }
    end
  end

  test "suggest_names with a named scope and order: :relation" do
    Member.create!(name: "Mia", created_at: 3.days.ago)
    Member.create!(name: "Max", created_at: 1.day.ago)
    Member.create!(name: "Mo", created_at: 2.days.ago)
    Member.define_singleton_method(:newest_first) { order(created_at: :desc) }
    MembersController.suggest_names :member, :name, scope: :newest_first, order: :relation

    get autocomplete_member_name_members_path(term: "m")

    assert_response :success
    assert_equal %w[Max Mo Mia], JSON.parse(response.body)
  ensure
    MembersController.suggest_names :member, :name, match: :start
    Member.singleton_class.remove_method(:newest_first) if Member.singleton_methods(false).include?(:newest_first)
  end

  test "a named scope that is not a relation is refused" do
    Member.create!(name: "Mia")
    Member.define_singleton_method(:not_a_scope) { [] }
    MembersController.suggest_names :member, :name, scope: :not_a_scope

    assert_raises(ArgumentError) { get autocomplete_member_name_members_path(term: "m") }
  ensure
    MembersController.suggest_names :member, :name, match: :start
    Member.singleton_class.remove_method(:not_a_scope) if Member.singleton_methods(false).include?(:not_a_scope)
  end

  # ---- 6. the field request check follows the engine action, not its name ---

  test "an app action that hands over to edit is checked for the _edit helper" do
    widget = Widget.create!(name: "Alpha")
    shown_only = Module.new { def shown_only_show(*) = "shown" }
    InlineFormsHelper.include(shown_only)
    WidgetsController.define_method(:edit_field) { edit }
    frame = "widget_#{widget.id}_name"

    with_row = lambda do |&block|
      WidgetsController.define_method(:review_row) { @inline_forms_attribute_list = [ [ :name, :shown_only ] ] }
      WidgetsController.before_action :review_row
      block.call
    ensure
      WidgetsController.skip_before_action :review_row, raise: false
      WidgetsController.remove_method(:review_row) if WidgetsController.method_defined?(:review_row, false)
    end

    with_routing do |set|
      set.draw do
        resources :widgets do
          get :edit_field, on: :member
        end
      end
      with_row.call do
        get "/widgets/#{widget.id}/edit_field", params: { attribute: "name", form_element: "shown_only", update: frame },
                                                headers: frame_headers(frame)
      end
    end

    assert_response :bad_request
  ensure
    shown_only.send(:remove_method, :shown_only_show)
    WidgetsController.remove_method(:edit_field) if WidgetsController.method_defined?(:edit_field, false)
  end
end
