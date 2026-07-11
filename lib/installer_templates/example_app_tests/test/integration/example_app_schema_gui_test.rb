# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# The dev-only schema-change GUI (InlineForms::SchemaController), mounted only
# in the example app. Non-destructive coverage: the new form renders and a
# preview of a brand-new scalar field on Apartment renders with no schema
# change. Apply (the actual generator run) is covered by the engine dummy suite
# (recording executor) and inline_forms_addto_generator_test, so this test does
# not mutate the generated app during the shared gate.
class ExampleAppSchemaGuiTest < ExampleAppIntegrationTestCase
  test "schema/new renders the add-a-field form" do
    get "/schema/new"
    assert_response :success
    assert_includes @response.body, "Form element"
    assert_includes @response.body, "text_field"
  end

  test "schema/preview shows a new scalar field on Apartment without changing the schema" do
    refute_includes Apartment.column_names, "staff_note",
      "precondition: staff_note must not already exist"

    post "/schema/preview",
         params: { model_name: "Apartment", attribute: "staff_note",
                   form_element: "text_field", after: "name" }

    assert_response :success
    assert_includes @response.body, "staff_note (new)"
    assert_includes @response.body, %(name="staff_note")

    Apartment.reset_column_information
    refute_includes Apartment.column_names, "staff_note",
      "preview must not add a column"
  end
end
