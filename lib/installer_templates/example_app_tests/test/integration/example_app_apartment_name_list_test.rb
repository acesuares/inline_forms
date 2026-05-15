# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Example app demo: inline field edit without the stock _show / _list UI.
# Each row uses text_field_show inside a span id="apartment_<id>_name".
class ExampleAppApartmentNameListTest < ExampleAppIntegrationTestCase
  setup do
    @apartments = 10.times.map do |i|
      Apartment.find_or_create_by!(name: "NameList Apt #{i}") do |a|
        a.title = "Title #{i}"
      end
    end
  end

  test "name list page is reachable and renders inline-edit targets for first 10 apartments" do
    get apartment_name_list_path
    assert_response :success

    Apartment.order(:id).limit(10).each do |apartment|
      assert_includes @response.body, %(id="apartment_#{apartment.id}_name"),
        "expected inline-edit wrapper for apartment #{apartment.id}"
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

  test "edit link for a name targets the field span and uses UJS remote" do
    apartment = @apartments.first
    get apartment_name_list_path
    assert_response :success

    assert_match(
      %r/href="[^"]*\/apartments\/#{apartment.id}\/edit[^"]*update=apartment_#{apartment.id}_name[^"]*"/,
      @response.body,
      "expected edit link with update= matching field span id"
    )
    assert_includes @response.body, 'data-remote="true"',
      "field edit still uses UJS until Turbo step 3"
  end
end
