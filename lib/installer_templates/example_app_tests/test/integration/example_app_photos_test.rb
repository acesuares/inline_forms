# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppPhotosTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.create!(name: "Beach", title: "Ocean view")
  end

  test "photos are not served as standalone html resource" do
    assert Photo.not_accessible_through_html?
    get photos_path
    assert_not response.successful?,
               "expected no standalone HTML index for not_accessible_through_html model (got #{response.status})"
  end

  test "can create a photo for an apartment" do
    assert_difference("Photo.count", 1) do
      Photo.create!(name: "Sunset", apartment: @apartment)
    end
  end

  test "nested photo destroy undo restores rich_text description" do
    photo = @apartment.photos.create!(name: "undo.jpg", caption: "c")
    body = "<p>Photo description survives undo</p>"
    field_frame = "apartment_#{@apartment.id}_photo_#{photo.id}_description"
    put photo_path(
      photo,
      attribute: "description",
      form_element: "rich_text",
      update: field_frame
    ), params: { description: body },
       headers: { "Turbo-Frame" => field_frame, "Accept" => "text/html" }
    assert_response :success
    assert_includes photo.reload.description.body.to_html, "survives undo"

    photo_id = photo.id
    row_frame = "apartment_#{@apartment.id}_photo_#{photo_id}"
    delete photo_path(photo, update: row_frame),
           headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success

    destroy_version = PaperTrail::Version.where(
      item_type: "Photo",
      item_id: photo_id,
      event: "destroy"
    ).order(:id).last
    post revert_photo_path(destroy_version, update: row_frame),
         headers: {
           "Turbo-Frame" => row_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes Photo.find(photo_id).description.body.to_html, "survives undo"
  end

  test "nested photo delete undo twice does not duplicate ActionText rows" do
    photo = @apartment.photos.create!(name: "twice.jpg", caption: "c")
    body = "<p>Twice undo description</p>"
    field_frame = "apartment_#{@apartment.id}_photo_#{photo.id}_description"
    put photo_path(
      photo,
      attribute: "description",
      form_element: "rich_text",
      update: field_frame
    ), params: { description: body },
       headers: { "Turbo-Frame" => field_frame, "Accept" => "text/html" }

    photo_id = photo.id
    row_frame = "apartment_#{@apartment.id}_photo_#{photo_id}"
    row_headers = { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    stream_headers = row_headers.merge("Accept" => "text/vnd.turbo-stream.html")

    2.times do
      delete photo_path(Photo.find(photo_id), update: row_frame), headers: row_headers
      assert_response :success

      destroy_version = PaperTrail::Version.where(
        item_type: "Photo",
        item_id: photo_id,
        event: "destroy"
      ).order(:id).last
      post revert_photo_path(destroy_version, update: row_frame), headers: stream_headers
      assert_response :success,
        "second delete/undo must not INSERT a duplicate action_text_rich_texts id"
    end

    assert_equal 1,
      ActionText::RichText.where(
        record_type: "Photo",
        record_id: photo_id,
        name: "description"
      ).count
    assert_includes Photo.find(photo_id).description.body.to_html, "Twice undo"
  end

  # Regression: PaperTrail records a non-empty changeset for `destroy` events,
  # so the versions panel shows a Restore link on `destroy` rows. Reverting a
  # `destroy` reifies a record with the original PK and `new_record? == true`.
  # Once the row has already been restored (undone), the old `@parent.save!`
  # re-INSERTed that PK -> `RecordNotUnique` (`UNIQUE constraint failed:
  # photos.id`). Revert must be idempotent: restoring a `destroy` version while
  # the row exists updates it in place instead of crashing.
  test "restoring a destroy version while the photo exists does not raise RecordNotUnique" do
    photo = @apartment.photos.create!(name: "restore.jpg", caption: "before")
    photo.update!(caption: "after")
    photo_id = photo.id

    row_frame = "apartment_#{@apartment.id}_photo_#{photo_id}"
    row_headers = { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    stream_headers = row_headers.merge("Accept" => "text/vnd.turbo-stream.html")

    delete photo_path(photo, update: row_frame), headers: row_headers
    assert_response :success

    destroy_version = PaperTrail::Version.where(
      item_type: "Photo",
      item_id: photo_id,
      event: "destroy"
    ).order(:id).last
    assert destroy_version, "expected a Photo destroy version"

    post revert_photo_path(destroy_version, update: row_frame), headers: stream_headers
    assert_response :success
    assert Photo.exists?(photo_id), "undo should have restored the photo row"

    # The row now exists again. Restoring the SAME destroy version (panel
    # Restore link, or a replayed undo) must not INSERT a duplicate id.
    post revert_photo_path(destroy_version, update: row_frame), headers: stream_headers
    assert_response :success,
      "restoring a destroy version while the row exists must not raise RecordNotUnique"
    assert_equal 1, Photo.where(id: photo_id).count
  end
end
