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
end
