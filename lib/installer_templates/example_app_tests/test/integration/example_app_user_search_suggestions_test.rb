# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# The users list's search box suggests names while the user types
# (`inline_forms_search_on :name, :email, suggest: { on: :name }`): the list
# itself answers ?suggest=1&term=… with a JSON array, from the users the
# signed-in user may see, and inline_forms/datalist_suggest.js fills the
# box's <datalist>.
class ExampleAppUserSearchSuggestionsTest < ExampleAppIntegrationTestCase
  setup do
    [ "Martina", "Tina Mart", "Tom" ].each_with_index do |name, i|
      User.create!(name: name, email: "suggest#{i}@example.com", locale: example_app_admin_user.locale,
                   password: "suggest999", password_confirmation: "suggest999")
    end
  end

  test "the users list has a search box with a suggestion list" do
    get users_path

    assert_response :success
    assert_select "input#input_search[list=input_search_suggestions][data-suggest-url=?]", "#{users_path}?suggest=1"
    assert_select "datalist#input_search_suggestions"
  end

  test "the list answers names that contain the term, in A-Z order" do
    get users_path(suggest: 1, term: "MAR")

    assert_response :success
    assert_equal "application/json", @response.media_type
    assert_equal [ "Martina", "Tina Mart" ], JSON.parse(@response.body)
  end

  test "suggestions come from names only, not from e-mail addresses" do
    get users_path(suggest: 1, term: "suggest")

    assert_equal [], JSON.parse(@response.body)
  end

  test "signed out there are no suggestions" do
    sign_out example_app_admin_user

    get users_path(suggest: 1, term: "mar")

    assert_response :redirect
  end

  test "the search box has accessible names" do
    get users_path

    assert_select "form[role=search] input#input_search[aria-label]"
    assert_select "form[role=search] a[aria-label] i.fi-x[aria-hidden=true]"
  end

  test "every controller can tell a suggestion request from a list view" do
    assert ApplicationController.new.respond_to?(:inline_forms_suggestion_request?, true),
           "ApplicationController inherits inline_forms_suggestion_request? for the app's own callbacks"
    refute ApplicationController.action_methods.include?("inline_forms_suggestion_request?")
  end

  test "the layout's script bundle carries the suggestion script" do
    get users_path

    script = @response.parsed_body.css("script[src]").map { |tag| tag["src"] }.find { |src| src.include?("inline_forms/inline_forms") }
    assert script, "the layout loads inline_forms/inline_forms.js"
    get script
    assert_response :success
    assert_includes @response.body, "window.datalistSuggestLoaded"
  end
end
