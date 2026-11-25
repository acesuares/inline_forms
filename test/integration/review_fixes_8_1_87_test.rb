# frozen_string_literal: true

require_relative "../integration_test_helper"

# A review of 8.1.85 and 8.1.86 (8.1.87): one sort key for a mixed values
# list, and tests for what 8.1.86 fixed without one.
class ReviewFixes8187Test < InlineFormsIntegrationTestCase
  ROOT = File.expand_path("../..", __dir__)

  def values_of(list)
    helpers = ApplicationController.helpers
    helpers.instance_variable_set(:@inline_forms_attribute_list, [ [ :priority, :dropdown_with_values, list ] ])
    helpers.send(:attribute_values, Widget.new, :priority)
  end

  # ---- 1. a mixed values list sorts the same way every time --------------------

  test "nil first, then numbers in numeric order, then everything else as text" do
    assert_equal [ 9, 10, "1a" ], values_of([ 10, 9, "1a" ]).map(&:last)
    assert_equal (0..12).to_a + [ "12+" ], values_of((0..12).to_a.reverse + [ "12+" ]).map(&:last)
    assert_equal [ nil, 1, 2.5, 3, "a", "b" ], values_of([ "b", 3, nil, 2.5, "a", 1 ]).map(&:last)
    %w[b a c].permutation.each do |order|
      assert_equal [ 1, 2, "a", "b", "c" ], values_of(order + [ 2, 1 ]).map(&:last)
    end
  end

  test "a values hash sorts its keys the same way" do
    assert_equal [ 9, 10, "1a" ], values_of({ 10 => "ten", "1a" => "one a", 9 => "nine" }).map(&:first)
  end

  # ---- 7. tests the review found missing ----------------------------------------

  test "the display allowlist drops the contents of <template> and <noscript>" do
    html = InlineForms.rich_text_display_html("<template><p>t</p></template><noscript>n</noscript><p>kept</p>").to_s

    assert_equal "<p>kept</p>", html
  end

  test "a plain-column Trix editor refuses a dropped or pasted file" do
    js = File.read(File.join(ROOT, "app/assets/javascripts/inline_forms/inline_forms.js"))
    listener = js[/document\.addEventListener\("trix-file-accept".*?\n  \}\);/m]

    assert listener, "inline_forms.js listens for trix-file-accept on the document"
    assert_includes listener, %(classList.contains("inline_forms-trix-no-files"))
    assert_includes listener, "event.preventDefault()"
  end

  test "order: :relation leaves out what the ability hides" do
    Member.create!(name: "Mia", created_at: 3.days.ago)
    Member.create!(name: "Max", created_at: 1.day.ago)
    Member.create!(name: "Mo", created_at: 2.days.ago)
    Member.define_singleton_method(:newest_first) { order(created_at: :desc) }
    MembersController.suggest_names :member, :name, scope: :newest_first, order: :relation
    Ability.restrictions = -> { cannot :read, Member, name: "Max" }

    get autocomplete_member_name_members_path(term: "m")

    assert_response :success
    assert_equal %w[Mo Mia], JSON.parse(response.body)
  ensure
    MembersController.suggest_names :member, :name, match: :start
    Member.singleton_class.remove_method(:newest_first) if Member.singleton_methods(false).include?(:newest_first)
  end

  test "order: :relation reads at most 10 pages of 4 x limit rows per column" do
    now = Time.current
    Member.insert_all(Array.new(480) { { name: "Ada", created_at: now, updated_at: now } })
    Member.create!(name: "Adam")
    queries = 0
    count = ->(*, payload) { queries += 1 if payload[:sql].include?("LIMIT") && payload[:name] != "SCHEMA" }

    found = ActiveSupport::Notifications.subscribed(count, "sql.active_record") do
      InlineForms::Suggestions.values(Member.all, :name, "ad", order: :relation)
    end

    assert_equal %w[Ada], found, "Adam lies past the 480 rows the window reads"
    assert_equal InlineForms::Suggestions::PAGES, queries
    assert_equal %w[Ada Adam], InlineForms::Suggestions.values(Member.all, :name, "ad")
  end
end
