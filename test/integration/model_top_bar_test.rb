# frozen_string_literal: true

require_relative "../integration_test_helper"

# Engine-owned model top bar: title + new-record + optional search region.
class ModelTopBarTest < InlineFormsIntegrationTestCase
  setup do
    @widget = Widget.create!(name: "Alpha")
    @machine = Machine.create!(name: "Press")
  end

  test "searchable model renders the engine generic search box" do
    get widgets_path

    assert_response :success
    assert_includes response.body, %(id="input_search")
    assert_includes response.body, %(id="inline_forms_model_top_bar")
    refute_includes response.body, "bespoke gizmo search"
  end

  test "non-searchable model renders no search box" do
    get machines_path

    assert_response :success
    assert_includes response.body, %(id="inline_forms_model_top_bar")
    refute_includes response.body, %(id="input_search")
  end

  test "bespoke _<model>_search partial wins over generic search" do
    get gizmos_path

    assert_response :success
    assert_includes response.body, %(id="bespoke_gizmo_search")
    refute_includes response.body, %(id="input_search")
  end

  test "generic search box filters the list via inline_forms_search_on" do
    Widget.create!(name: "Beta")

    get widgets_path(search: "Alp")

    assert_response :success
    assert_includes response.body, "Alpha"
    refute_includes response.body, "Beta"
  end

  test "no schema GUI link in the engine top bar, even with the schema routes drawn" do
    assert respond_to?(:inline_forms_schema_new_path), "precondition: the dummy draws the schema routes"
    get widgets_path

    assert_response :success
    refute_includes response.body, "+ field"
    refute_includes response.body, %(href="#{inline_forms_schema_new_path}")
  end

  test "non-model page with no @Klass renders title only, no new-record link" do
    get stats_path

    assert_response :success
    assert_includes response.body, %(id="inline_forms_model_top_bar")
    assert_includes response.body, %(id="stats_report")
    refute_includes response.body, "new_button"
    refute_includes response.body, %(id="input_search")
  end

  # The class body runs whenever the model loads (eager loading,
  # assets:precompile with no database); quoting there needed a connection.
  test "inline_forms_search_on needs no database connection until the search runs" do
    model = Class.new(ApplicationRecord) do
      self.table_name = "widgets"
      def self.name = "OfflineWidget"
    end
    no_db = ->(*) { raise "database touched at declaration" }
    %i[connection lease_connection with_connection].each { |m| model.define_singleton_method(m, &no_db) }

    model.inline_forms_search_on :name

    assert model.inline_forms_searchable?
    %i[connection lease_connection with_connection].each { |m| model.singleton_class.remove_method(m) }
    Widget.create!(name: "Gamma")
    assert_equal [ "Gamma" ], model.inline_forms_search("amm").pluck(:name)
    # Built once, on the first search.
    assert_same model.inline_forms_search_clause, model.inline_forms_search_clause
  end
end
