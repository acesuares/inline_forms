# frozen_string_literal: true

require_relative "../integration_test_helper"

# The batch pipeline (phases 1-3): drafting intents into a batch, freeze on
# submit, token-authenticated export + status callback, and import/replay
# via a recording executor (never mutates the dummy tree).
class SchemaBatchPipelineTest < InlineFormsIntegrationTestCase
  def teardown
    InlineFormsSchemaGui.export_token = nil
    super
  end

  def draft_widget_field!(attribute: "warehouse_note", label: "Warehouse note")
    post inline_forms_schema_draft_path,
         params: { model_name: "Widget", attribute: attribute,
                   form_element: "text_field", after: "name", label: label, locale: "en" }
  end

  # -- phase 1: drafting + freeze ------------------------------------------

  test "drafting an intent creates a draft batch (the cart) and index shows it" do
    draft_widget_field!
    assert_response :redirect

    batch = InlineForms::SchemaBatch.with_status(:draft).first
    assert batch, "draft batch created"
    assert_equal 1, batch.intents.count
    intent = batch.intents.first
    assert_equal %w[Widget warehouse_note text_field name], [
      intent.target_model, intent.attr_name, intent.form_element, intent.after_attr
    ]

    get inline_forms_schema_index_path
    assert_response :success
    assert_includes response.body, "warehouse_note"
    assert_includes response.body, "Submit batch"
  end

  test "invalid intents are rejected at drafting time" do
    post inline_forms_schema_draft_path,
         params: { model_name: "Widget", attribute: "name", form_element: "text_field" }
    assert_response :success # renders :new with the error
    assert_includes response.body, "already has a name column"
    assert_equal 0, InlineForms::SchemaIntentRecord.count
  end

  test "submit freezes the batch: no more adds, edits or removals; digest sealed" do
    draft_widget_field!
    post inline_forms_schema_submit_batch_path
    assert_response :redirect

    batch = InlineForms::SchemaBatch.last
    assert_equal "submitted", batch.status
    assert batch.submitted_at
    assert_match(/\Asha256:/, batch.content_digest)

    intent = batch.intents.first
    intent.label = "changed"
    refute intent.save, "frozen intent must not save"
    refute intent.destroy, "frozen intent must not be destroyed"

    refute batch.intents.create(target_model: "Widget", attr_name: "late_one",
                                form_element: "text_field").persisted?,
           "no new intents into a frozen batch"

    batch.window_at = 2.days.from_now
    refute batch.save, "frozen batch attributes must not change"

    # A new draft goes into a NEW batch.
    draft_widget_field!(attribute: "second_note")
    assert_equal 2, InlineForms::SchemaBatch.count
  end

  test "submitting an empty batch is refused" do
    post inline_forms_schema_submit_batch_path
    assert_redirected_to inline_forms_schema_index_path
    assert_equal 0, InlineForms::SchemaBatch.where(status: "submitted").count
  end

  test "status transitions follow the pipeline; illegal jumps raise" do
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last.submit!

    batch.transition!(:processing)
    batch.transition!(:ready, git_sha: "abc123")
    assert_equal "abc123", batch.git_sha
    assert_raises(ArgumentError) { batch.transition!(:submitted) }
    batch.transition!(:applied)
    assert batch.applied_at
  end

  # -- phase 3: machine endpoints ------------------------------------------

  test "export 404s without a configured token and 401s with a wrong one" do
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last.submit!

    get inline_forms_schema_export_path(batch)
    assert_response :not_found

    InlineFormsSchemaGui.export_token = "sekret"
    get inline_forms_schema_export_path(batch), headers: { "Authorization" => "Bearer wrong" }
    assert_response :unauthorized
  end

  test "export returns the sealed payload; draft batches are refused" do
    InlineFormsSchemaGui.export_token = "sekret"
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last

    get inline_forms_schema_export_path(batch), headers: { "Authorization" => "Bearer sekret" }
    assert_response :conflict

    batch.submit!
    get inline_forms_schema_export_path(batch), headers: { "Authorization" => "Bearer sekret" }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload["format"]
    assert_equal batch.content_digest, payload["digest"]
    assert_equal "warehouse_note", payload["intents"].first["attribute"]
  end

  test "status callback drives the batch through the pipeline" do
    InlineFormsSchemaGui.export_token = "sekret"
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last.submit!

    post inline_forms_schema_batch_status_path(batch),
         params: { status: "processing" }, headers: { "Authorization" => "Bearer sekret" }
    assert_response :success
    assert_equal "processing", batch.reload.status

    post inline_forms_schema_batch_status_path(batch),
         params: { status: "applied" }, headers: { "Authorization" => "Bearer sekret" }
    assert_response :unprocessable_entity, "processing -> applied skips ready"

    post inline_forms_schema_batch_status_path(batch),
         params: { status: "failed", error: "test gate red" },
         headers: { "Authorization" => "Bearer sekret" }
    assert_equal "failed", batch.reload.status
    assert_equal "test gate red", batch.error
  end

  # -- phase 2: export/import round trip -----------------------------------

  test "import verifies the digest and replays intents through the executor" do
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last.submit!

    payload = InlineFormsSchemaGui::BatchExport.payload(batch)

    recorded = []
    labels = []
    import = InlineFormsSchemaGui::BatchImport.new(
      payload,
      executor: ->(args, _root) { recorded << args },
      label_writer: ->(**kwargs) { labels << kwargs; "/dev/null/labels.yml" }
    )
    result = import.apply!(destination_root: Dir.tmpdir)

    assert_equal 1, result.applied
    assert_equal [ "Widget", "warehouse_note:text_field", "--after=name" ], recorded.first
    assert_equal "Warehouse note", labels.first[:label]
    assert_includes result.plan.join("\n"), "inline_forms_addto Widget warehouse_note:text_field"
  end

  test "import rejects a tampered payload (digest mismatch) and stale intents" do
    draft_widget_field!
    batch = InlineForms::SchemaBatch.last.submit!
    payload = InlineFormsSchemaGui::BatchExport.payload(batch)

    tampered = payload.deep_dup
    tampered["intents"].first["attribute"] = "evil_column"
    error = assert_raises(InlineFormsSchemaGui::BatchImport::ImportError) do
      InlineFormsSchemaGui::BatchImport.new(tampered).verify!
    end
    assert_match(/digest mismatch/, error.message)

    # A column that already exists in THIS checkout fails per-intent validation.
    stale = InlineFormsSchemaGui::BatchExport.payload(batch)
    stale["intents"].first["attribute"] = "name"
    stale["digest"] = "sha256:#{Digest::SHA256.hexdigest(JSON.generate(stale['intents']))}"
    error = assert_raises(InlineFormsSchemaGui::BatchImport::ImportError) do
      InlineFormsSchemaGui::BatchImport.new(stale).verify!
    end
    assert_match(/already has a name column/, error.message)
  end
end
