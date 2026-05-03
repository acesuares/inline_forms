# frozen_string_literal: true

require "test_helper"

class ExampleAppApartmentPhotoTest < ActiveSupport::TestCase
  setup do
    @apartment = Apartment.create!(name: "North", title: "Tower")
    @photo = Photo.create!(name: "Lobby", apartment: @apartment)
  end

  test "photo belongs to apartment" do
    assert_equal @apartment, @photo.apartment
  end

  test "apartment has many photos" do
    assert_includes @apartment.photos.to_a, @photo
  end

  test "photo model hides resource from standalone html crud" do
    assert Photo.not_accessible_through_html?
  end

  test "apartment model allows standalone html crud" do
    assert_not Apartment.not_accessible_through_html?
  end
end
