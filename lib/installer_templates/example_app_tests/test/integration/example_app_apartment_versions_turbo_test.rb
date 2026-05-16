# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppApartmentVersionsTurboTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.first || Apartment.create!(name: "Versions Turbo", title: "T")
    @versions_frame = "apartment_#{@apartment.id}_versions"
    @headers = { "Turbo-Frame" => @versions_frame, "Accept" => "text/html" }
  end

  test "versions list opens inside matching turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame), headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    assert_includes @response.body, "Changeset"
    refute_includes @response.body, 'data-remote="true"'
  end

  test "versions list close returns panel header inside turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame, close: true),
        headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    refute_includes @response.body, "Changeset"
  end
end
