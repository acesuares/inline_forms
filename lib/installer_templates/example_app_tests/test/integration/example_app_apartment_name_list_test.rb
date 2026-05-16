# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Custom page demo: same turbo-field contract as stock _show, without opening the panel.
class ExampleAppApartmentNameListTest < ExampleAppIntegrationTestCase
  setup do
    @apartments = 10.times.map do |i|
      Apartment.find_or_create_by!(name: "NameList Apt #{i}") do |a|
        a.title = "Title #{i}"
      end
    end
  end

  test "name list page is reachable and renders turbo-frame inline-edit targets for first 10 apartments" do
    get apartment_name_list_path
    assert_response :success

    Apartment.order(:id).limit(10).each do |apartment|
      assert_includes @response.body, %(<turbo-frame id="apartment_#{apartment.id}_name">),
        "expected turbo-frame wrapper for apartment #{apartment.id}"
      assert_includes @response.body, apartment.name,
        "expected apartment name on page"
    end
  end

  test "more menu links to apartment name list" do
    get apartments_path
    assert_response :success
    assert_includes @response.body, apartment_name_list_path,
      "expected More menu link to name list"
    assert_includes @response.body, "Apartment names (first 10)"
  end

  test "name list field links use turbo-frame navigation not UJS remote" do
    apartment = @apartments.first
    get apartment_name_list_path
    assert_response :success

    frame_html = @response.body[%r{<turbo-frame id="apartment_#{apartment.id}_name">.*?</turbo-frame>}m]
    assert frame_html, "expected turbo-frame for apartment #{apartment.id}"
    assert_match(
      %r/href="[^"]*\/apartments\/#{apartment.id}\/edit[^"]*update=apartment_#{apartment.id}_name[^"]*"/,
      frame_html,
      "expected edit link with update= matching turbo-frame id"
    )
    refute_includes frame_html, 'data-remote="true"',
      "field edits use Turbo frames, not UJS"
  end

  test "name list reuses stock turbo field edit update cycle" do
    apartment = @apartments.first
    frame_id = "apartment_#{apartment.id}_name"
    turbo_headers = { "Turbo-Frame" => frame_id }

    get edit_apartment_path(
      apartment,
      attribute: "name",
      form_element: "text_field",
      update: frame_id
    ), headers: turbo_headers
    assert_response :success

    put apartment_path(
      apartment,
      attribute: "name",
      form_element: "text_field",
      update: frame_id
    ), params: { name: "Name List Turbo" }, headers: turbo_headers
    assert_response :success
    assert_equal "Name List Turbo", apartment.reload.name
  end
end
