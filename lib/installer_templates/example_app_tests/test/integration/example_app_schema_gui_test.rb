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

  # Batch pipeline (phases 1-3): the install generator created the tables,
  # so draft -> submit -> token export works end to end in a generated app.
  # No codegen happens (batch mode never generates in the request cycle), so
  # this cannot mutate the app during the shared gate.
  test "batch drafting, freeze on submit, and token-authenticated export" do
    post "/schema/draft",
         params: { model_name: "Apartment", attribute: "staff_note",
                   form_element: "text_field", after: "name", label: "Staff note" }
    assert_response :redirect

    batch = InlineForms::SchemaBatch.with_status(:draft).last
    assert_equal 1, batch.intents.count

    get "/schema"
    assert_response :success
    assert_includes @response.body, "staff_note"

    post "/schema/batch/submit"
    batch.reload
    assert_equal "submitted", batch.status
    assert_match(/\Asha256:/, batch.content_digest)
    refute batch.intents.first.update(label: "changed"), "frozen after submit"

    original_token = InlineFormsSchemaGui.export_token
    InlineFormsSchemaGui.export_token = "gate-test-token"
    begin
      get "/schema/batches/#{batch.id}/export.json"
      assert_response :unauthorized, "token configured but not provided"

      get "/schema/batches/#{batch.id}/export.json",
          headers: { "Authorization" => "Bearer gate-test-token" }
      assert_response :success
      payload = JSON.parse(@response.body)
      assert_equal batch.content_digest, payload["digest"]
      assert_equal "staff_note", payload["intents"].first["attribute"]
    ensure
      InlineFormsSchemaGui.export_token = original_token
    end
  end
end
