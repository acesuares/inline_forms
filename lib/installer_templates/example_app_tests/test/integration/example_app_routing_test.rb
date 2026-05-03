# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppRoutingTest < ExampleAppIntegrationTestCase
  test "root routes to apartments index" do
    get root_path
    assert_response :success
  end

  test "apartments index is reachable when signed in" do
    get apartments_path
    assert_response :success
  end
end
