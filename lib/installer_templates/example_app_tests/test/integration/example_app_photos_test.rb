# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppPhotosTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.create!(name: "Beach", title: "Ocean view")
  end

  test "photos are not served as standalone html resource" do
    assert Photo.not_accessible_through_html?
    get photos_path
    assert_not response.successful?,
               "expected no standalone HTML index for not_accessible_through_html model (got #{response.status})"
  end

  test "can create a photo for an apartment" do
    assert_difference("Photo.count", 1) do
      Photo.create!(name: "Sunset", apartment: @apartment)
    end
  end
end
