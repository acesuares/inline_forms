# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppApartmentNameRequiredTest < ExampleAppIntegrationTestCase
  setup do
    @frame = "apartments_list"
    @frame_headers = { "Turbo-Frame" => @frame, "Accept" => "text/html" }
  end

  test "top-level create without name does not persist" do
    assert_no_difference("Apartment.count") do
      post apartments_path(update: @frame),
        params: { title: "Missing name" },
        headers: @frame_headers
    end
    assert_response :success
    assert_includes @response.body, 'name="name"'
    assert_includes @response.body, 'class="edit_form"'
  end
end
