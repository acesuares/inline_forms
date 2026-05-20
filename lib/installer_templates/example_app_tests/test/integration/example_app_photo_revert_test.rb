# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# 7.9.0 regression: revert from the versions panel for a Photo whose
# `image` column changed must put back the previous CarrierWave file
# bytes, not just the previous filename string. Relies on the
# `ImageUploader` knobs the installer ships:
#
#   * `CarrierWave.configure { config.remove_previously_stored_files_after_update = false }`
#     (config/initializers/carrierwave.rb)
#   * `remove!` no-op
#   * unique per-upload filename prefix
#
# See https://stackoverflow.com/questions/9423279/papertrail-and-carrierwave
class ExampleAppPhotoRevertTest < ExampleAppIntegrationTestCase
  # Mirror the setup of ExampleAppApartmentPhotosPaginationTest: re-seed
  # Konferensha photos from db/seed_images/ so the test asserts against
  # real CarrierWave file mounts without depending on dev DB state.
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
  end

  test "revert restores previous CarrierWave file bytes on disk" do
    photo = @apartment.photos.first!
    original_identifier = photo.image.identifier
    original_path = photo.image.path
    assert File.exist?(original_path), "expected seeded photo file on disk: #{original_path}"
    original_size = File.size(original_path)

    seed_dir = Rails.root.join("db", "seed_images")
    seeds = Dir.glob(seed_dir.join("*.{jpg,jpeg,png,gif}"), File::FNM_CASEFOLD).sort
    replacement = seeds.find do |abs|
      File.basename(abs) != photo.name && File.size(abs) != original_size
    end || seeds.find { |abs| File.basename(abs) != photo.name }
    assert replacement,
      "need at least one seed image different from the photo's current mount"
    refute_equal File.size(replacement), original_size,
      "test needs a replacement file with a different byte length so the assertion is meaningful"

    frame_id = "apartment_#{@apartment.id}_photo_#{photo.id}_image"
    turbo_headers = { "Turbo-Frame" => frame_id, "Accept" => "text/html" }
    mime = (replacement.to_s.downcase.end_with?(".png") ? "image/png" : "image/jpeg")
    uploaded = Rack::Test::UploadedFile.new(replacement, mime)
    put photo_path(
      photo,
      attribute: "image",
      form_element: "image_field",
      update: frame_id
    ),
        params: { image: uploaded },
        headers: turbo_headers
    assert_response :success
    photo.reload
    refute_equal original_identifier, photo.image.identifier,
      "update should have changed the image identifier"

    version = photo.versions.where(event: "update").order(:id).last
    assert version, "expected a Photo update version after the image PUT"

    row_frame = "apartment_#{@apartment.id}_photo_#{photo.id}"
    versions_frame = "apartment_#{@apartment.id}_photo_#{photo.id}_versions"
    post revert_photo_path(version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")

    photo.reload
    assert_equal original_identifier, photo.image.identifier,
      "revert should restore the previous CarrierWave identifier"
    assert File.exist?(photo.image.path),
      "revert should leave the previous file bytes on disk (carrierwave config)"
    assert_equal original_size, File.size(photo.image.path),
      "previous file bytes must be byte-identical to the original"
  end
end
