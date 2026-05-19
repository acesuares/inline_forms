# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Smoke test for rollout step 2 of stuff/ujs-to-turbo.md (gem-side):
# the nested has_many list (apartments -> photos) is now wrapped in a
# <turbo-frame> and pagination is no longer remote: true. Relies on
# the SeedKonferenshaPhotos migration that the inline_forms installer
# generates when invoked with --example: it creates a "Konferensha"
# Apartment with one Photo per file in db/seed_images/, and the gem
# ships 12 sample jpgs in pics/, so combined with `Photo.per_page = 5`
# (also set by the installer) this gallery paginates 5 / 5 / 2.
class ExampleAppApartmentPhotosPaginationTest < ExampleAppIntegrationTestCase
  # `bundle exec rails test` loads the test DB from db/schema.rb, which is
  # DDL-only -- the SeedKonferenshaPhotos migration's row inserts never
  # land in db/test.sqlite3. We re-seed here from the same db/seed_images/
  # the installer copied into the app so the test asserts against real
  # records (and real CarrierWave file mounts) without depending on
  # development-DB state.
  setup do
    @apartment = Apartment.find_or_create_by!(name: "Konferensha") do |a|
      a.title = "Konferensha sobre Papiamentu"
    end
    seed_dir = Rails.root.join("db", "seed_images")
    if seed_dir.directory?
      Dir.glob(seed_dir.join("*.{jpg,jpeg,png,gif}"), File::FNM_CASEFOLD).sort.each do |abs|
        base = File.basename(abs)
        next if Photo.exists?(name: base, apartment_id: @apartment.id)
        File.open(abs, "rb") do |io|
          Photo.create!(
            name: base,
            caption: "Konferensha foto #{base}",
            apartment: @apartment,
            image: io
          )
        end
      end
    end
    @update_span = "apartment_#{@apartment.id}_photos_list"
  end

  test "seed migration left at least 6 photos under Konferensha so pagination triggers" do
    assert @apartment.photos.count >= 6,
      "expected SeedKonferenshaPhotos to seed >= 6 photos for Konferensha; " \
      "got #{@apartment.photos.count}. Check db/seed_images/ and the migration."
  end

  test "Photo.per_page is overridden so will_paginate splits the gallery" do
    assert_equal 5, Photo.per_page,
      "expected the installer to set `self.per_page = 5` on Photo so the seeded gallery paginates"
  end

  test "nested photos index without Turbo-Frame header renders full inline_forms layout (bookmark / full navigation)" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    assert_match(
      /id="outer_container"/,
      @response.body,
      "direct or full-page GET /photos?... must use the inline_forms layout " \
      "so the page is styled; `layout: false` used to emit only a bare <turbo-frame> " \
      "which looks broken in the address bar."
    )
    assert_match(
      %r{<turbo-frame\s+id="#{Regexp.escape(@update_span)}"},
      @response.body,
      "expected the gallery frame inside the layout body"
    )
  end

  test "nested photos index with Turbo-Frame header uses minimal layout without app chrome" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    ),
        headers: { "Turbo-Frame" => @update_span }
    assert_response :success

    assert_match(
      %r{<turbo-frame\s+id="#{Regexp.escape(@update_span)}"},
      @response.body,
      "expected Turbo frame navigation to receive a matching <turbo-frame id=\"#{@update_span}\">"
    )
    refute_match(
      /id="outer_container"/,
      @response.body,
      "frame requests should not pay for the full inline_forms chrome; use turbo_rails/frame layout"
    )
  end

  test "nested photos index is wrapped in a <turbo-frame> instead of remote-UJS <div>" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    assert_match(
      %r{<turbo-frame\s+id="#{Regexp.escape(@update_span)}"},
      @response.body,
      "expected the nested photos list to render as <turbo-frame id=\"#{@update_span}\">"
    )

    refute_match(
      %r{<div[^>]+class="list_container"[^>]+id="#{Regexp.escape(@update_span)}"},
      @response.body,
      "nested photos list should no longer use the legacy <div class=\"list_container\"> wrapper"
    )
  end

  test "nested photos pagination renders will_paginate links inside the frame" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    assert_match(
      /<(?:div|nav)[^>]+class="[^"]*\bpagination\b[^"]*"/,
      @response.body,
      "expected will_paginate to render a .pagination element (gallery has more rows than Photo.per_page)"
    )

    refute_match(
      /class="next_page"[^>]*data-remote="true"/,
      @response.body,
      "pagination links should no longer carry data-remote=\"true\" (Turbo Frame handles in-frame nav)"
    )
  end

  test "pagination links carry the same update= as the surrounding turbo-frame id" do
    # This is the regression class that broke "Next" in 7.2.1: the
    # legacy UJS pagination passed `update=apartment_<id>_photos`
    # (the OUTER wrapper id from _show.html.erb, which list.js.erb
    # used as the swap target). Turbo Frames swaps by id-match between
    # the frame in the DOM and a frame in the response, so when a Next
    # click re-rendered _list with update_span derived from the URL,
    # the response contained `<turbo-frame id="apartment_<id>_photos">`
    # while the page held `<turbo-frame id="apartment_<id>_photos_list">`,
    # and Turbo logged "the response did not contain the expected
    # <turbo-frame>" and dropped the swap. The `update=` param on every
    # pagination link must be the same id as the surrounding frame.
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    page_link_updates =
      @response.body.scan(/href="[^"]*\?[^"]*update=([^&"]+)[^"]*"/).flatten

    assert page_link_updates.any? { |u| u == @update_span },
      "expected at least one pagination link to carry update=#{@update_span} " \
      "(matching the <turbo-frame id=\"#{@update_span}\">), got updates=#{page_link_updates.inspect}"

    refute page_link_updates.any? { |u| u == @update_span.sub(/_list\z/, "") },
      "no pagination link should still carry the legacy outer-wrapper id " \
      "(#{@update_span.sub(/_list\z/, "")}) -- Turbo Frame can't swap on that id"
  end

  test "top-level apartment rows do NOT carry data-turbo=\"false\" (would poison nested frames)" do
    # 7.2.2 broke pagination of the inner photos <turbo-frame> because
    # the top-level apartment row was emitting data-turbo="false" too.
    # When show.js.erb swaps the inline edit (containing the nested
    # <turbo-frame>) into that row, every link inside the nested frame
    # -- including pagination links -- has the row as an ancestor.
    # Turbo's Session.elementIsNavigatable does
    # `findClosestRecursively(link, "[data-turbo]")` and does NOT stop
    # at the intervening <turbo-frame>; it picks up the row's
    # data-turbo="false" and refuses to intercept the click, so the
    # browser does a full-page navigation to /photos?page=N&... and
    # the user sees the bare partial without a layout. The attribute
    # must stay scoped to NESTED rows (which need the opt-out for
    # their swapped-in inline-edit forms); top-level rows must NOT
    # carry it.
    get apartments_path
    assert_response :success

    refute_match(
      /<div[^>]+class="[^"]*\btop-level\b[^"]*"[^>]*data-turbo="false"|<div[^>]+data-turbo="false"[^>]*class="[^"]*\btop-level\b[^"]*"/,
      @response.body,
      "top-level list rows must not carry data-turbo=\"false\"; that attribute would " \
      "be inherited by every link inside any nested <turbo-frame> swapped into the row"
    )
  end

  test "nested photo rows are turbo-framed with Turbo presentation links (no data-turbo false on row)" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    sample_row_id = "apartment_#{@apartment.id}_photo_#{@apartment.photos.first.id}"
    assert_match(
      %r{<turbo-frame[^>]*\bid="#{Regexp.escape(sample_row_id)}"},
      @response.body,
      "expected each nested photo row to be a <turbo-frame id=\"#{sample_row_id}\">"
    )
    refute_match(
      %r{<turbo-frame[^>]*id="#{Regexp.escape(sample_row_id)}"[^>]*data-turbo="false"},
      @response.body,
      "nested turbo-frame rows must not opt out of Turbo (field cancel / pagination live inside frames)"
    )
    assert_select %(turbo-frame##{sample_row_id} a[data-turbo='true'][data-turbo-frame='#{sample_row_id}']), minimum: 1
  end

  test "nested Photo versions restore targets nested row turbo-frame not bare photo id" do
    photo = @apartment.photos.first!
    original_name = photo.name
    photo.update!(name: "#{original_name}-changed")
    row_id = "apartment_#{@apartment.id}_photo_#{photo.id}"
    versions_frame = "#{row_id}_versions"
    version = photo.versions.where(event: "update").order(:id).last
    assert version, "expected an update version to revert"

    get list_versions_photo_path(photo, update: versions_frame),
        headers: { "Turbo-Frame" => versions_frame, "Accept" => "text/html" }
    assert_response :success
    assert_includes @response.body, "data-turbo-frame=\"#{row_id}\"",
      "restore must target the nested row frame (#{row_id}), not photo_#{photo.id}"

    # 7.9.0: revert always responds with turbo-stream (the legacy
    # `format.html` fallback was dropped).
    post revert_photo_path(version.id, update: row_id),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_id}")
    assert_equal original_name, photo.reload.name
  end

  test "nested Photo row opens and closes via Turbo HTML (not_accessible_through_html model)" do
    photo = @apartment.photos.first!
    row_id = "apartment_#{@apartment.id}_photo_#{photo.id}"
    row_headers = { "Turbo-Frame" => row_id, "Accept" => "text/html" }

    get photo_path(photo, update: row_id), headers: row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{row_id}">)
    assert_includes @response.body, "object_presentation"

    get photo_path(photo, update: row_id, close: true), headers: row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{row_id}">)
    refute_includes @response.body, "object_presentation"
  end

  test "nested Photo name field cancel returns field show HTML (Turbo)" do
    photo = @apartment.photos.first!
    frame_id = "apartment_#{@apartment.id}_photo_#{photo.id}_name"
    turbo_headers = { "Turbo-Frame" => frame_id, "Accept" => "text/html" }

    get edit_photo_path(
      photo,
      attribute: "name",
      form_element: "text_field",
      update: frame_id
    ), headers: turbo_headers
    assert_response :success

    get photo_path(
      photo,
      attribute: "name",
      form_element: "text_field",
      update: frame_id
    ), headers: turbo_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame_id}">)
    refute_includes @response.body, 'name="name"',
      "cancel must return read-only field, not the edit form"
  end

  # Step 3 (ujs-to-turbo.md): nested `not_accessible_through_html?` Photo + CarrierWave
  # `image` must accept Turbo-driven multipart PUT inside the field `<turbo-frame>`
  # (no `UnknownFormat` / 406 after DB write — regression class from 7.2.0).
  test "nested Photo image field updates via Turbo multipart PUT inside field frame" do
    photo = @apartment.photos.first!
    frame_id = "apartment_#{@apartment.id}_photo_#{photo.id}_image"
    turbo_headers = { "Turbo-Frame" => frame_id, "Accept" => "text/html" }

    get edit_photo_path(
      photo,
      attribute: "image",
      form_element: "image_field",
      update: frame_id
    ), headers: turbo_headers
    assert_response :success
    assert_includes @response.body, %(enctype="multipart/form-data"),
      "image edit form must stay multipart when Turbo omits remote: true"
    assert_includes @response.body, %(<turbo-frame id="#{frame_id}">)

    seed_dir = Rails.root.join("db", "seed_images")
    jpgs = Dir.glob(seed_dir.join("*.{jpg,jpeg}"), File::FNM_CASEFOLD).sort
    assert_operator jpgs.size, :>=, 2,
      "need at least two seed jpgs so replacement can differ from current mount"

    replacement = jpgs.find { |abs| File.basename(abs) != photo.name } || jpgs.last
    uploaded = Rack::Test::UploadedFile.new(replacement, "image/jpeg")

    put photo_path(
      photo,
      attribute: "image",
      form_element: "image_field",
      update: frame_id
    ),
        params: { image: uploaded },
        headers: turbo_headers

    assert_response :success,
      "multipart image update must respond with HTML (not 406 UnknownFormat)"
    assert_includes @response.body, %(<turbo-frame id="#{frame_id}">)
    refute_match(/UnknownFormat|406 Not Acceptable/, @response.body)

    photo.reload
    assert photo.image.present?, "expected CarrierWave mount after Turbo multipart PUT"
  end

  # 7.5.2 regression: after cancel / update on a field, the swapped
  # `<turbo-frame id="…">` must contain a Turbo link
  # (`data-turbo="true" data-turbo-frame="_self"`) so the user can re-open
  # the editor. 7.5.1 emitted `data-remote="true"`, which jquery_ujs
  # intercepts as a JS request the controller does not register, so the
  # second click silently fails (no swap, no edit form).
  test "nested Photo image field show after update has Turbo (not data-remote) link" do
    photo = @apartment.photos.first!
    frame_id = "apartment_#{@apartment.id}_photo_#{photo.id}_image"
    turbo_headers = { "Turbo-Frame" => frame_id, "Accept" => "text/html" }

    seed_dir = Rails.root.join("db", "seed_images")
    jpgs = Dir.glob(seed_dir.join("*.{jpg,jpeg}"), File::FNM_CASEFOLD).sort
    replacement = jpgs.find { |abs| File.basename(abs) != photo.name } || jpgs.last
    uploaded = Rack::Test::UploadedFile.new(replacement, "image/jpeg")

    put photo_path(
      photo,
      attribute: "image",
      form_element: "image_field",
      update: frame_id
    ),
        params: { image: uploaded },
        headers: turbo_headers
    assert_response :success
    refute_match(
      /data-remote="true"/,
      @response.body,
      "field_show after Turbo update must use Turbo data attributes; " \
      "data-remote=\"true\" hits jquery_ujs (no JS responder) and the " \
      "second click silently fails."
    )
    assert_match(
      /data-turbo="true"/,
      @response.body,
      "expected Turbo data attribute on the inline-edit link inside the swapped field frame"
    )
  end

  # Same regression on the cancel path (no DB write): clicking the field
  # cancel returns the read-only field; the link inside must be a Turbo link
  # so the user can re-open the editor.
  test "nested Photo image field show after cancel has Turbo (not data-remote) link" do
    photo = @apartment.photos.first!
    frame_id = "apartment_#{@apartment.id}_photo_#{photo.id}_image"
    turbo_headers = { "Turbo-Frame" => frame_id, "Accept" => "text/html" }

    get photo_path(
      photo,
      attribute: "image",
      form_element: "image_field",
      update: frame_id
    ), headers: turbo_headers
    assert_response :success
    refute_match(/data-remote="true"/, @response.body,
      "cancel-side field_show must not regress to UJS data-remote=\"true\"")
    assert_match(/data-turbo="true"/, @response.body)
  end

  test "nested Photo new cancel and create via Turbo inside associated list frame" do
    frame = "apartment_#{@apartment.id}_photos"
    headers = { "Turbo-Frame" => frame, "Accept" => "text/html" }

    get new_photo_path(update: frame, parent_class: "Apartment", parent_id: @apartment.id),
        headers: headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    assert_includes @response.body, "stylesheet", "new form must use inline_forms layout (styled)"
    assert_includes @response.body, %(enctype="multipart/form-data")
    assert_includes @response.body, 'class="edit_form"'
    assert_includes @response.body, 'name="name"'

    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: frame,
      ul_needed: true
    ), headers: headers
    assert_response :success
    assert_match %r{<turbo-frame id="#{frame}"}, @response.body
    assert_match %r{<turbo-frame id="#{@update_span}"}, @response.body

    seed = Rails.root.join("db/seed_images/dsc00099.jpg")
    uploaded = Rack::Test::UploadedFile.new(seed, "image/jpeg")

    assert_difference("Photo.count", 1) do
      post photos_path(
        update: frame,
        parent_class: "Apartment",
        parent_id: @apartment.id
      ),
           params: {
             name: "curl_new_photo.jpg",
             caption: "from turbo test",
             image: uploaded
           },
           headers: headers
    end
    assert_response :success
    assert_match %r{<turbo-frame id="#{frame}"}, @response.body
    assert_match %r{<turbo-frame id="#{@update_span}"}, @response.body
    assert_includes @response.body, "curl_new_photo.jpg"
  end
end
