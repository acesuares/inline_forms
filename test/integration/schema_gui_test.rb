# frozen_string_literal: true

require_relative "../integration_test_helper"

# The dev-only schema-change GUI (InlineForms::SchemaController): new -> preview
# (no migration) -> apply (runs the addto generator, no db:migrate). Apply is
# exercised with a RECORDING executor so the suite never mutates the dummy tree.
class SchemaGuiTest < InlineFormsIntegrationTestCase
  def teardown
    InlineForms::SchemaController.generator_executor = nil
    super
  end

  test "new renders the form with supported elements" do
    get inline_forms_schema_new_path
    assert_response :success
    assert_includes response.body, "Model"
    assert_includes response.body, "Form element"
    assert_includes response.body, "text_field"
    assert_includes response.body, "Preview"
  end

  test "preview shows the field at the right position with no migration" do
    post inline_forms_schema_preview_path,
         params: { model_name: "Widget", attribute: "internal_note",
                   form_element: "text_field", after: "name" }
    assert_response :success
    assert_includes response.body, "internal_note (new)"
    # rendered live widget for the new field
    assert_includes response.body, %(name="internal_note")
    # placement: internal_note appears after name in the rendered order
    assert response.body.index("name (new)").nil?
    assert response.body.index(">name<") < response.body.index("internal_note (new)")

    # No schema change happened.
    refute_includes Widget.column_names, "internal_note"
    assert_empty Dir.glob(Rails.root.join("db/migrate/*_inline_forms_add_to_*.rb"))
  end

  test "an unsupported (non-scalar) element is rejected with an error" do
    post inline_forms_schema_preview_path,
         params: { model_name: "Widget", attribute: "vendor", form_element: "dropdown" }
    assert_response :success
    assert_includes response.body, "Unsupported form element"
  end

  test "invalid input re-renders the form with an error" do
    post inline_forms_schema_preview_path,
         params: { model_name: "Widget", attribute: "Bad Name", form_element: "text_field" }
    assert_response :success
    assert_includes response.body, "lowercase letters"
  end

  test "apply invokes the generator (no db:migrate) via the injected executor" do
    recorded = []
    InlineForms::SchemaController.generator_executor = ->(args, _root) { recorded << args }

    post inline_forms_schema_path,
         params: { model_name: "Widget", attribute: "internal_note",
                   form_element: "text_field", after: "name" }
    assert_response :success
    assert_includes response.body, "Applied"
    assert_includes response.body, "db:migrate" # the "you run this" instruction
    assert_equal 1, recorded.size
    assert_equal [ "Widget", "internal_note:text_field", "--after=name" ], recorded.first
    # The generator never wrote a migration (recorder), and we never migrated.
    refute_includes Widget.column_names, "internal_note"
  end

  test "reachable only outside production" do
    original = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("production")
    get inline_forms_schema_new_path
    assert_response :not_found
  ensure
    Rails.env = original
  end
end
