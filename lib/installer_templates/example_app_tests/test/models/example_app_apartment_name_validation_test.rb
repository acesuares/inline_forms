# frozen_string_literal: true

require "test_helper"

class ExampleAppApartmentNameValidationTest < ActiveSupport::TestCase
  test "apartment requires name" do
    apartment = Apartment.new(title: "No name")
    assert_not apartment.valid?
    assert_includes apartment.errors[:name], "can't be blank"
  end

  test "apartment is valid with name" do
    apartment = Apartment.new(name: "North", title: "Tower")
    assert apartment.valid?
  end
end
