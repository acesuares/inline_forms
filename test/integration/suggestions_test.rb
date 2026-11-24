# frozen_string_literal: true

require_relative "../integration_test_helper"

# Search suggestions: InlineForms::Suggestions (the query), the controller
# macro suggest_names, the engine's search box with
# `inline_forms_search_on …, suggest: …`, and suggest_field_tag.
class SuggestionsTest < InlineFormsIntegrationTestCase
  def names(*list) = list.each { |name| Member.create!(name: name) }

  def values(term, **options) = InlineForms::Suggestions.values(Member.all, :name, term, **options)

  def suggestions = JSON.parse(response.body)

  # ---- the query -------------------------------------------------------------

  test "contains finds the term anywhere, in any case" do
    names "Martina", "tinaMart", "tinartma", "Tom"

    assert_equal %w[Martina tinaMart tinartma], values("ma")
    assert_equal %w[Martina tinaMart tinartma], values("MA", match: :contains)
  end

  test "start finds the term only at the start of the value" do
    names "Martina", "tinaMart", "tinartma", "mart"

    assert_equal %w[mart Martina], values("ma", match: :start)
  end

  test "word finds the term at the start of any word" do
    names "Martina", "Anna Maria", "tinaMart", "Tom"

    assert_equal [ "Anna Maria", "Martina" ], values("ma", match: :word)
  end

  test "word also starts after a hyphen or an apostrophe" do
    names "Jean-Marc", "O'Brien", "D’Abreu", "Marcus", "Lamarck", "Obrienne"

    assert_equal %w[Jean-Marc Marcus], values("marc", match: :word)
    assert_equal [ "O'Brien" ], values("brien", match: :word)
    assert_equal [ "D’Abreu" ], values("abreu", match: :word)
    assert_equal [ "Jean-Marc" ], values("jean-m", match: :word)
  end

  test "percent and underscore in the term are taken literally" do
    names "100% wool", "1000 wool", "a_b", "axb", 'back\slash', "backslash"

    assert_equal [ "100% wool" ], values("100%")
    assert_equal [ "a_b" ], values("a_b")
    assert_equal [ 'back\slash' ], values('k\s')
    assert_equal [ "100% wool" ], values("100%", match: :start)
  end

  test "each value once, stripped and in any case, in A-Z order, at most limit" do
    names "Adriana ", "Adriana", "adriana", "Bea", "Ada", "Cor", "Dirk"

    assert_equal %w[Ada Adriana Bea], values("a", limit: 3)
    assert_equal %w[Ada Adriana], values("ad")
  end

  test "an empty or blank term gives nothing" do
    names "Ann"

    assert_equal [], values("")
    assert_equal [], values("   ")
    assert_equal [], values(nil)
  end

  test "an unknown match or a wrong limit is refused" do
    assert_raises(ArgumentError) { values("a", match: :fuzzy) }
    assert_raises(ArgumentError) { values("a", limit: 0) }
    assert_raises(ArgumentError) { Class.new(InlineFormsController) { suggest_names :member, :name, match: :middle } }
  end

  test "several columns are merged into one list" do
    Widget.create!(name: "Zara", notes: "Martha's notes")
    Widget.create!(name: "Mara", notes: "zora's notes")

    assert_equal [ "Mara", "Martha's notes", "Zara" ], InlineForms::Suggestions.values(Widget.all, %w[name notes], "ar")
    assert_equal [ "Mara", "Martha's notes" ], InlineForms::Suggestions.values(Widget.all, %w[name notes], "ar", limit: 2)
  end

  test "a default order on the relation does not get in the way" do
    names "Bob", "Abby"

    assert_equal %w[Abby Bob], InlineForms::Suggestions.values(Member.order(name: :desc), :name, "b")
  end

  # ---- suggest_names ---------------------------------------------------------

  test "suggest_names answers a JSON array, here from the start of the name" do
    names "Martina", "tinaMart", "Mark"

    get autocomplete_member_name_members_path(term: "mar")

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal %w[Mark Martina], suggestions
  end

  test "suggest_names gives only what the user may read" do
    names "Mark", "Marta"
    Ability.restrictions = -> { cannot :read, Member, name: "Marta" }

    get autocomplete_member_name_members_path(term: "mar")

    assert_equal %w[Mark], suggestions
  end

  test "suggest_names is an action the ability has to allow" do
    names "Mark"
    Ability.restrictions = -> { cannot :autocomplete_member_name, Member }

    get autocomplete_member_name_members_path(term: "mar")

    assert_response :forbidden
  end

  test "suggest_names runs the controller's scope, and finds the term anywhere by default" do
    %w[Alpha Hidden Shida].each { |name| Widget.create!(name: name) }

    get autocomplete_widget_name_widgets_path(term: "id")

    assert_equal %w[Shida], suggestions
  end

  test "suggest_names with an empty term answers []" do
    names "Mark"

    get autocomplete_member_name_members_path

    assert_equal [], suggestions
  end

  # ---- the engine's search box -----------------------------------------------

  test "a model with suggest: gets a search box with a suggestion list" do
    get members_path

    assert_select "input#input_search[list=input_search_suggestions][autocomplete=off]" do |input|
      assert_equal "#{members_path}?suggest=1", input.first["data-suggest-url"]
    end
    assert_select "datalist#input_search_suggestions"
  end

  test "the search box has accessible names, with or without suggestions" do
    [ members_path, widgets_path ].each do |path|
      get path

      assert_select "form[role=search]"
      assert_select "input#input_search[aria-label=search]"
      assert_select "form[role=search] a[aria-label=reset][title=reset] i.fi-x[aria-hidden=true]"
    end
  end

  test "inline_forms_suggestion_request? tells the suggestions from a list view" do
    seen = []
    MembersController.define_method(:record_suggestion_request) { seen << inline_forms_suggestion_request? }
    MembersController.after_action :record_suggestion_request, only: :index

    get members_path
    get members_path(suggest: 1, term: "ma")
    get members_path(search: "ma")

    assert_equal [ false, true, false ], seen
  ensure
    MembersController.skip_after_action :record_suggestion_request, raise: false
    MembersController.remove_method(:record_suggestion_request) if MembersController.method_defined?(:record_suggestion_request)
  end

  test "a model without suggest: keeps the plain search box" do
    get widgets_path

    assert_select "input#input_search"
    assert_select "input#input_search[list]", count: 0
    assert_select "datalist", count: 0
  end

  test "the list answers the search box's suggestions with the model's options" do
    names "Anna Maria", "Martina", "Mark", "Marta", "tinaMart"

    get members_path(suggest: 1, term: "ma")

    assert_response :ok
    assert_equal [ "Anna Maria", "Mark", "Marta" ], suggestions
  end

  test "the search box's suggestions come only from records the user may see" do
    names "Mark", "Marta"
    Ability.restrictions = -> { cannot :read, Member, name: "Mark" }

    get members_path(suggest: 1, term: "mar")

    assert_equal %w[Marta], suggestions
  end

  test "a model without suggest: has no suggestions" do
    Widget.create!(name: "Alpha")

    get widgets_path(suggest: 1, term: "al")

    assert_response :not_found
  end

  test "suggest: options are checked when the model is declared" do
    model = Class.new(ApplicationRecord) do
      self.table_name = "members"
      def self.name = "SuggestingMember"
    end

    model.inline_forms_search_on :name, :phase_id, suggest: true
    assert_equal({ on: %w[name phase_id], match: :contains, limit: 12 }, model.inline_forms_suggestions)
    model.inline_forms_search_on :name, suggest: { on: :name, match: "start", limit: 5 }
    assert_equal({ on: %w[name], match: :start, limit: 5 }, model.inline_forms_suggestions)
    model.inline_forms_search_on :name
    assert_nil model.inline_forms_suggestions

    assert_raises(ArgumentError) { model.inline_forms_search_on :name, suggest: :yes }
    assert_raises(ArgumentError) { model.inline_forms_search_on :name, suggest: { match: :fuzzy } }
    assert_raises(ArgumentError) { model.inline_forms_search_on :name, suggest: { columns: [ :name ] } }
    assert_raises(ArgumentError) { model.inline_forms_search_on :name, suggest: { on: [] } }
  end

  # ---- suggest_field_tag and the script --------------------------------------

  test "suggest_field_tag is a text field with a list, and an empty datalist" do
    html = ApplicationController.helpers.suggest_field_tag("search", "Ann", "/members/autocomplete_member_name", placeholder: "name", data: { suggest_min: 3 })
    field = Nokogiri::HTML5.fragment(html)

    input = field.at_css("input")
    assert_equal "text", input["type"]
    assert_equal "search_suggestions", input["list"]
    assert_equal "off", input["autocomplete"]
    assert_equal "/members/autocomplete_member_name", input["data-suggest-url"]
    assert_equal "3", input["data-suggest-min"]
    assert_equal "name", input["placeholder"]
    assert_equal "Ann", input["value"]
    assert_equal "search_suggestions", field.at_css("datalist")["id"]
    assert_empty field.at_css("datalist").children

    other = Nokogiri::HTML5.fragment(ApplicationController.helpers.suggest_field_tag("q[name]", nil, "/x", list: "own"))
    assert_equal "own", other.at_css("input")["list"]
    assert_equal "own", other.at_css("datalist")["id"]
    assert_equal "q_name__suggestions", Nokogiri::HTML5.fragment(ApplicationController.helpers.suggest_field_tag("q[name]", nil, "/x")).at_css("datalist")["id"]
  end

  test "the engine's script bundle carries the suggestion script, once-guarded" do
    root = File.expand_path("../..", __dir__)
    bundle = File.read(File.join(root, "app/assets/javascripts/inline_forms/inline_forms.js"))
    script = File.read(File.join(root, "app/assets/javascripts/inline_forms/datalist_suggest.js"))

    assert_includes bundle, "//= require inline_forms/datalist_suggest"
    assert_includes script, "if (window.datalistSuggestLoaded) { return; }"
    refute_match(/\b(jQuery|\$\()/, script)
  end
end
