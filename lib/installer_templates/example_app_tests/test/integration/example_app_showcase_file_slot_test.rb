# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# FormElementShowcase#manual is a declared file slot (generated from
# `manual:simple_file_field`: InlineForms::StoredFiles, manual_data /
# manual_content_type columns, InlineForms.file_routes in routes.rb, the
# inline_forms:file_trash migration). Exercises the generated wiring end to
# end as the superadmin: upload, replace, remove, undo, purge, the global
# trash page, and that reverting an unrelated edit keeps the file.
class ExampleAppShowcaseFileSlotTest < ExampleAppIntegrationTestCase
  PDF = "%PDF-1.4 example file slot".b
  OTHER = "%PDF-1.4 a different file".b

  setup do
    @showcase = FormElementShowcase.create!(title: "File slot demo")
    @frame = "form_element_showcase_#{@showcase.id}_manual"
  end

  def upload(bytes, name)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), "application/pdf", original_filename: name)
  end

  def put_manual(bytes, name)
    patch form_element_showcase_path(@showcase, attribute: "manual", form_element: "simple_file_field", update: @frame),
          params: { manual: upload(bytes, name) }, headers: { "Turbo-Frame" => @frame }
  end

  def stream_headers
    { "Turbo-Frame" => @frame, "Accept" => "text/vnd.turbo-stream.html" }
  end

  test "the generated model declares the slot and skips it in PaperTrail" do
    assert FormElementShowcase.inline_forms_file_slot?(:manual)
    assert_includes FormElementShowcase.paper_trail_options[:skip], "manual_data"
  end

  test "upload, replace, remove, undo and purge" do
    put_manual(PDF, "first.pdf")
    assert_response :success
    assert_equal PDF, @showcase.reload.manual_data

    put_manual(OTHER, "second.pdf")
    assert_equal OTHER, @showcase.reload.manual_data
    replaced = InlineForms::TrashedFile.trash_entries.where(reason: "replaced").sole
    assert_equal "first.pdf", replaced.filename

    post remove_file_form_element_showcase_path(@showcase, attribute: "manual", update: @frame), headers: stream_headers
    assert_response :success
    assert_nil @showcase.reload.manual_data
    removed = InlineForms::TrashedFile.trash_entries.where(reason: "removed").sole

    post restore_file_form_element_showcase_path(@showcase, attribute: "manual", trash_id: removed.id, update: @frame),
         headers: stream_headers
    assert_equal OTHER, @showcase.reload.manual_data

    post purge_file_form_element_showcase_path(@showcase, attribute: "manual", trash_id: replaced.id, update: @frame),
         headers: stream_headers
    assert replaced.reload.purged?
    assert_nil replaced.file_data
  end

  test "download_file sends the stored bytes" do
    put_manual(PDF, "first.pdf")
    get download_file_form_element_showcase_path(@showcase, attribute: "manual")

    assert_response :success
    assert_equal PDF, response.body.b
  end

  test "reverting an unrelated edit keeps the file" do
    put_manual(PDF, "first.pdf")
    @showcase.update!(title: "Renamed")
    version = @showcase.versions.where(event: "update").last
    row = "form_element_showcase_#{@showcase.id}"

    post revert_form_element_showcase_path(version, update: row),
         headers: { "Turbo-Frame" => row, "Accept" => "text/vnd.turbo-stream.html" }

    @showcase.reload
    assert_equal "File slot demo", @showcase.title
    assert_equal PDF, @showcase.manual_data
  end

  test "the global trash page renders for the superadmin" do
    put_manual(PDF, "first.pdf")
    post remove_file_form_element_showcase_path(@showcase, attribute: "manual", update: @frame), headers: stream_headers

    get inline_forms_file_trash_path
    assert_response :success
    assert_includes response.body, "first.pdf"
  end
end
