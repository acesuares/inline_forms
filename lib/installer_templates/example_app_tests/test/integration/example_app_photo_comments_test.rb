# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Nesting-in-nesting (Apartment -> Photo -> Comment): a Photo opened inside an
# apartment's photos panel exposes its own :associated comments panel, and the
# whole nested CRUD contract works one level deeper.
class ExampleAppPhotoCommentsTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.create!(name: "Nested", title: "Nesting demo")
    @photo = @apartment.photos.create!(name: "room.jpg", caption: "the room")
  end

  test "comments are not served as standalone html resource" do
    assert Comment.not_accessible_through_html?
    get comments_path
    assert_not response.successful?,
               "expected no standalone HTML index for not_accessible_through_html model (got #{response.status})"
  end

  test "opened nested photo row exposes the comments panel with its new link" do
    row_frame = "apartment_#{@apartment.id}_photo_#{@photo.id}"
    get photo_path(@photo, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success

    panel = "photo_#{@photo.id}_comments"
    assert_includes @response.body, %(id="#{panel}_list_auto_header")
    assert_includes @response.body, %(<turbo-frame id="#{panel}")
    assert_match(
      %r{/comments/new\?[^"]*parent_id=#{@photo.id}},
      @response.body,
      "expected the comments panel's new-record link for the photo"
    )
  end

  test "comments panel lists existing comments" do
    comment = @photo.comments.create!(body: "First!")
    row_frame = "apartment_#{@apartment.id}_photo_#{@photo.id}"
    get photo_path(@photo, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body,
      %(<turbo-frame id="photo_#{@photo.id}_comment_#{comment.id}">)
    assert_includes @response.body, "First!"
  end

  test "new comment form renders inside the comments panel frame" do
    panel = "photo_#{@photo.id}_comments"
    get new_comment_path(update: panel, parent_class: "Photo", parent_id: @photo.id),
        headers: { "Turbo-Frame" => panel, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{panel}">)
    assert_includes @response.body, 'name="body"'
  end

  test "nested comment create persists with the photo FK and returns the panel frame" do
    panel = "photo_#{@photo.id}_comments"
    assert_difference("Comment.count", 1) do
      post comments_path(update: panel, parent_class: "Photo", parent_id: @photo.id),
           params: { body: "Great view from here" },
           headers: { "Turbo-Frame" => panel,
                      "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end
    assert_response :success
    # Comment has no :associated panel of its own, so open-after-create does
    # not fire; the nested flow keeps the plain frame response.
    assert_equal "text/html", @response.media_type
    assert_includes @response.body, %(<turbo-frame id="#{panel}">)

    comment = Comment.find_by!(body: "Great view from here")
    assert_equal @photo.id, comment.photo_id
  end

  test "nested comment row opens and closes" do
    comment = @photo.comments.create!(body: "Open me")
    row_frame = "photo_#{@photo.id}_comment_#{comment.id}"

    get comment_path(comment, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{row_frame}">)
    assert_includes @response.body, "Open me"

    get comment_path(comment, update: row_frame, close: true),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{row_frame}">)
  end
end
