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

  test "row container opts out of Turbo so swapped-in UJS forms (replace photo etc.) keep working" do
    get photos_path(
      parent_class: "Apartment",
      parent_id: @apartment.id,
      update: @update_span,
      ul_needed: true
    )
    assert_response :success

    # The container-level opt-out is what protects the inline-edit /
    # replace-photo flow: when a user replaces a photo, show.js.erb /
    # edit.js.erb does $('#<row_id>').html(<form>), so the multipart
    # form that submits the upload is a descendant of this row. With
    # data-turbo="false" on the row, Turbo doesn't intercept that
    # submission -- jquery-ujs + remotipart do, the request goes out
    # with Accept: text/javascript, and the controller's format.js
    # branch handles it. Without this, Turbo Frames would send
    # Accept: text/html and the update action (no format.html for
    # not_accessible_through_html? models like Photo) raises
    # UnknownFormat AFTER the DB write -- a 406 with a corrupted UI.
    sample_row_id = "apartment_#{@apartment.id}_photo_#{@apartment.photos.first.id}"
    assert_match(
      %r{<div[^>]+id="#{Regexp.escape(sample_row_id)}"[^>]*data-turbo="false"|<div[^>]+data-turbo="false"[^>]*id="#{Regexp.escape(sample_row_id)}"},
      @response.body,
      "expected the per-row container (id=\"#{sample_row_id}\") to carry data-turbo=\"false\" " \
      "so swapped-in UJS forms inherit the Turbo opt-out"
    )
  end
end
