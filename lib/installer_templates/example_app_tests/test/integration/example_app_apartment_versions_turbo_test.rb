# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppApartmentVersionsTurboTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.first || Apartment.create!(name: "Versions Turbo", title: "T")
    @versions_frame = "apartment_#{@apartment.id}_versions"
    @headers = { "Turbo-Frame" => @versions_frame, "Accept" => "text/html" }
  end

  test "versions list opens inside matching turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame), headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    assert_includes @response.body, "Changeset"
    refute_includes @response.body, 'data-remote="true"'
  end

  test "versions list close returns panel header inside turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame, close: true),
        headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    refute_includes @response.body, "Changeset"
  end

  test "expanded row versions open link uses Turbo not UJS remote" do
    row_frame = "apartment_#{@apartment.id}"
    get apartment_path(@apartment, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success
    assert_select "turbo-frame##{@versions_frame} a[data-turbo='true'][data-turbo-frame='#{@versions_frame}']", minimum: 1
    refute_select "turbo-frame##{@versions_frame} a[data-remote='true']"
  end

  test "restore link in versions list requests turbo-stream (nested versions frame)" do
    apt = Apartment.create!(name: "Stream Link", title: "T")
    apt.update!(title: "T2")
    vf = "apartment_#{apt.id}_versions"
    get list_versions_apartment_path(apt, update: vf),
        headers: { "Turbo-Frame" => vf, "Accept" => "text/html" }
    assert_response :success
    assert_match(/data-turbo-stream="true"/, @response.body,
      "restore from inside …_versions must use turbo-stream to avoid Turbo-Frame mismatch")
  end

  test "revert from versions list closes row via turbo-stream when Turbo-Frame is versions" do
    apt = Apartment.create!(name: "Versions Stream Revert", title: "Before")
    apt.update!(title: "After")
    row_frame = "apartment_#{apt.id}"
    versions_frame = "#{row_frame}_versions"
    version = apt.versions.where(event: "update").order(:id).last
    assert version, "expected an update version to revert"

    post revert_apartment_path(version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")
    assert_equal "Before", apt.reload.title
  end

  test "revert from versions list closes row via Turbo POST on row frame" do
    apt = Apartment.create!(name: "Versions Revert", title: "Before")
    apt.update!(title: "After")
    row_frame = "apartment_#{apt.id}"
    versions_frame = "#{row_frame}_versions"
    # 7.9.0 dropped the `format.html` fallback in `revert`; the restore link
    # always requests a turbo-stream now, even when the click happened on
    # the row frame, so the test mirrors that contract.
    row_headers = {
      "Turbo-Frame" => row_frame,
      "Accept" => "text/vnd.turbo-stream.html"
    }

    version = apt.versions.where(event: "update").order(:id).last
    assert version, "expected an update version to revert"

    post revert_apartment_path(version.id, update: row_frame), headers: row_headers
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")
    assert_equal "Before", apt.reload.title
  end

  test "revert from versions list restores rich_text body via turbo-stream" do
    apt = Apartment.create!(name: "RichText Revert", title: "T")
    apt.update!(description: "<p>old body</p>")
    apt.update!(description: "<p>new body</p>")

    rich_text = ActionText::RichText.find_by!(
      record_type: Apartment.name, record_id: apt.id, name: "description"
    )
    rich_text_version = rich_text.versions.where(event: "update").order(:id).last
    assert rich_text_version,
      "expected a PaperTrail update version on ActionText::RichText for the description edit"

    row_frame = "apartment_#{apt.id}"
    versions_frame = "#{row_frame}_versions"
    post revert_apartment_path(rich_text_version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")

    apt.reload
    assert_includes apt.description.body.to_html, "old body",
      "rich_text revert should restore the previous body content"
  end

  # PaperTrail::Version#reify returns nil for `create` events (no prior state).
  # For ActionText::RichText we treat reverting a `create` as "undo the
  # creation": destroy the rich_text record so the parent's field reverts
  # to empty. This keeps Restore symmetric regardless of whether the
  # field's first rich_text save happened to be empty (reverting v2 update
  # returns to empty) or already had content (reverting v1 create destroys
  # the row = empty). The user-reported asymmetry was: Apartment's first
  # rich_text save was empty in the example data so Restore visibly
  # cleared the field via an update revert; nested Photo's first
  # rich_text save had content so the create was the only Restore target
  # and used to be hidden / a no-op.
  test "revert on rich_text create destroys the rich_text record so the field becomes empty" do
    apt = Apartment.create!(name: "RichText Create Revert", title: "T")
    apt.update!(description: "<p>only body</p>")

    rich_text = ActionText::RichText.find_by!(
      record_type: Apartment.name, record_id: apt.id, name: "description"
    )
    create_version = rich_text.versions.where(event: "create").order(:id).first
    assert create_version, "expected a PaperTrail create version on the rich_text record"

    row_frame = "apartment_#{apt.id}"
    versions_frame = "#{row_frame}_versions"
    post revert_apartment_path(create_version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")

    apt.reload
    assert_not apt.description.body.present?,
      "reverting a rich_text create must clear the field"
    refute ActionText::RichText.exists?(
      record_type: Apartment.name, record_id: apt.id, name: "description"
    ), "the underlying ActionText::RichText row must be destroyed by the revert"
  end

  test "revert on nested Photo rich_text create destroys the rich_text record" do
    apt = Apartment.create!(name: "Photo RT Create Revert", title: "T")
    photo = apt.photos.create!(name: "p.jpg", caption: "x")
    photo.update!(description: "<p>photo body</p>")

    rich_text = ActionText::RichText.find_by!(
      record_type: Photo.name, record_id: photo.id, name: "description"
    )
    create_version = rich_text.versions.where(event: "create").order(:id).first
    assert create_version,
      "expected a PaperTrail create version on the Photo's description rich_text"

    row_frame = "apartment_#{apt.id}_photo_#{photo.id}"
    versions_frame = "#{row_frame}_versions"
    post revert_photo_path(create_version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")

    photo.reload
    assert_not photo.description.body.present?,
      "reverting a Photo rich_text create must clear the description"
    refute ActionText::RichText.exists?(
      record_type: Photo.name, record_id: photo.id, name: "description"
    ), "the Photo's ActionText::RichText row must be destroyed by the revert"
  end

  # Pair with the model template change in `lib/generators/templates/model.erb`
  # (`has_paper_trail on: [:create, :update, :destroy]`): PaperTrail 16 tracks
  # `:touch` by default, and ActionText's `belongs_to :record, touch: true`
  # fires `parent.touch` on every rich-text save, producing parent-side
  # `update` versions with `changeset == {}`. The versions panel reified
  # those to the same state (no-op Restore). Opt out of `:touch` and no such
  # row appears.
  test "creating a record with a rich_text body does not append a touch-only parent update" do
    apt = Apartment.create!(name: "Touch Free", title: "T", description: "<p>seed</p>")
    update_events_with_nothing_to_replay = apt.versions.where(event: "update").select do |v|
      v.changeset.nil? || v.changeset.except("updated_at").empty?
    end
    assert_empty update_events_with_nothing_to_replay,
      "Apartment should not gain a touch-driven empty-changeset update version on rich_text save"
  end

  # Defensive view-level guard (covers legacy apps still tracking :touch and
  # any other empty-update source — e.g. CarrierWave callback flips that
  # change nothing user-visible).
  test "versions list hides Restore link on empty-changeset update rows" do
    apt = Apartment.create!(name: "Empty Update Hidden", title: "T")
    # Simulate a touch-driven update version (legacy `has_paper_trail`
    # without `on:` filter, or any future :touch source).
    PaperTrail::Version.create!(
      item_type: apt.class.name,
      item_id: apt.id,
      event: "update",
      whodunnit: "system",
      object: nil,
      object_changes: nil,
      created_at: Time.current
    )
    empty_v = PaperTrail::Version.where(item_type: apt.class.name, item_id: apt.id, event: "update").last
    assert empty_v.changeset.nil? || empty_v.changeset.except("updated_at").empty?

    vf = "apartment_#{apt.id}_versions"
    get list_versions_apartment_path(apt, update: vf),
        headers: { "Turbo-Frame" => vf, "Accept" => "text/html" }
    assert_response :success
    refute_includes @response.body, "/apartments/#{empty_v.id}/revert",
      "Restore link must be hidden for empty-changeset update versions"
  end

  # Primary (`:kind == :primary`) create rows still hide their Restore link:
  # reverting a primary create would mean destroying the record itself,
  # which is what the Destroy button is for. Only rich_text creates get a
  # Restore link (it destroys just the ActionText::RichText row).
  test "versions list hides Restore link on primary create rows but keeps it on update rows" do
    apt = Apartment.create!(name: "Create Link Hidden", title: "Before")
    apt.update!(title: "After")
    vf = "apartment_#{apt.id}_versions"
    get list_versions_apartment_path(apt, update: vf),
        headers: { "Turbo-Frame" => vf, "Accept" => "text/html" }
    assert_response :success

    update_v = apt.versions.where(event: "update").order(:id).last
    create_v = apt.versions.where(event: "create").order(:id).first
    assert update_v && create_v, "expected both create and update versions on the parent"

    assert_includes @response.body, "/apartments/#{update_v.id}/revert",
      "Restore link must remain for update versions"
    refute_includes @response.body, "/apartments/#{create_v.id}/revert",
      "Restore link must be hidden for primary create versions (reify nil; Destroy is the user-facing action)"
  end

  # Conversely, rich_text create rows MUST keep their Restore link — that
  # is the only way to undo "I added content" when the field was created
  # in one save with non-empty content (the originally reported asymmetry
  # vs. fields whose first save happened to be empty).
  test "versions list shows Restore link on rich_text create rows" do
    apt = Apartment.create!(name: "RT Create Link Shown", title: "T")
    apt.update!(description: "<p>seed body</p>")
    rich_text = ActionText::RichText.find_by!(
      record_type: Apartment.name, record_id: apt.id, name: "description"
    )
    rt_create_v = rich_text.versions.where(event: "create").order(:id).first
    assert rt_create_v

    vf = "apartment_#{apt.id}_versions"
    get list_versions_apartment_path(apt, update: vf),
        headers: { "Turbo-Frame" => vf, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body, "/apartments/#{rt_create_v.id}/revert",
      "Restore link must be present on rich_text create rows so the create can be undone"
  end
end
