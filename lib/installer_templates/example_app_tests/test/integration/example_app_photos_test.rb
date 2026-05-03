# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppPhotosTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.create!(name: "Beach", title: "Ocean view")
  end

  test "photos are not served as standalone html resource" do
    assert Photo.not_accessible_through_html?
    assert_raises(ActionController::UnknownFormat) do
      get photos_path
    end
  end

  test "can create a photo for an apartment" do
    assert_difference("Photo.count", 1) do
      Photo.create!(name: "Sunset", apartment: @apartment)
    end
  end
end
