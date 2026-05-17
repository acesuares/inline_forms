# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppValidationHintsTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.find_or_create_by!(name: "Konferensha") do |a|
      a.title = "Konferensha sobre Papiamentu"
    end
    @row_frame = "apartment_#{@apartment.id}"
    @row_headers = { "Turbo-Frame" => @row_frame, "Accept" => "text/html" }
    @list_frame = "apartments_list"
    @list_headers = { "Turbo-Frame" => @list_frame, "Accept" => "text/html" }
  end

  test "show panel name label uses hidden HTML source not title attribute" do
    get apartment_path(@apartment, update: @row_frame), headers: @row_headers
    assert_response :success

    hint_id = "validation_hints_apartment_#{@apartment.id}_name"
    assert_includes @response.body, %(class="validation-hint-trigger has-tip tip-top")
    assert_includes @response.body, %(data-validation-hints-source="#{hint_id}")
    assert_includes @response.body, %(id="#{hint_id}")
    assert_includes @response.body, "Name can&#39;t be blank"
    assert_includes @response.body, '<ul class="validation-hints-list">'
    refute_match(%r{title="&lt;ul}, @response.body)
    refute_match(%r{title='<ul}, @response.body)
  end

  test "new apartment form shows validation hint on name" do
    get new_apartment_path(update: @list_frame), headers: @list_headers
    assert_response :success

    hint_id = "validation_hints_apartment_new_name"
    assert_includes @response.body, %(data-validation-hints-source="#{hint_id}")
    assert_includes @response.body, %(id="#{hint_id}")
    assert_includes @response.body, "Name can&#39;t be blank"
    assert_includes @response.body, '<ul class="validation-hints-list">'
  end
end
