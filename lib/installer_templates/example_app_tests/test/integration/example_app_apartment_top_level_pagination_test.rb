# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Step 4: top-level index pagination swaps `<turbo-frame id="apartments_list">`.
class ExampleAppApartmentTopLevelPaginationTest < ExampleAppIntegrationTestCase
  setup do
    @frame = "apartments_list"
    @frame_headers = { "Turbo-Frame" => @frame, "Accept" => "text/html" }
    @original_per_page = Apartment.per_page
    Apartment.per_page = 3
    6.times do |i|
      Apartment.find_or_create_by!(name: "Paginate Apt #{i}") do |a|
        a.title = "Pagination seed #{i}"
      end
    end
  end

  teardown do
    Apartment.per_page = @original_per_page
  end

  test "top-level pagination links target apartments_list frame id" do
    get apartments_path
    assert_response :success
    assert_match %r{class="pagination"}, @response.body
    assert_match(
      /update=apartments_list/,
      @response.body,
      "pagination must pass update=apartments_list for Turbo frame swap"
    )
  end

  test "top-level page 2 returns matching turbo-frame with Turbo-Frame header" do
    get apartments_path(page: 2, update: @frame, ul_needed: true), headers: @frame_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame}")
    refute_match(/id="outer_container"/, @response.body)
  end
end
