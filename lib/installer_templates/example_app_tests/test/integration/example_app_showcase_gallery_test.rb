# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# multi_image_field (FormElementShowcase#gallery, 8.1.28): a mount_uploaders
# (plural) CarrierWave column serialized as a JSON array. First example-app
# coverage for this Tier 1 element.
class ExampleAppShowcaseGalleryTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "Gallery demo")
    src = Rails.root.join("db", "seed_uploads", "sample_cover.png")
    if @showcase.gallery.blank? && src.file?
      File.open(src, "rb") { |io| @showcase.gallery = [io] }
      @showcase.save!
    end
  end

  test "show renders the gallery images from the plural uploader" do
    skip "seed image missing" if @showcase.gallery.blank?

    frame = "form_element_showcase_#{@showcase.id}"
    get form_element_showcase_path(@showcase, update: frame),
        headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}_gallery">)
    # mount_uploaders store_dir => uploads/form_element_showcase/gallery/:id/
    assert_includes @response.body, "uploads/form_element_showcase/gallery",
      "expected an <img> from the gallery uploader array"
  end

  test "edit renders a multiple file input submitting gallery[]" do
    frame = "form_element_showcase_#{@showcase.id}_gallery"
    get edit_form_element_showcase_path(
      @showcase,
      attribute: "gallery",
      form_element: "multi_image_field",
      update: frame
    ), headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    assert_includes @response.body, %(type="file")
    assert_includes @response.body, %(name="gallery[]")
    assert_includes @response.body, %(multiple="multiple")
  end

  test "empty gallery renders the inline-edit plus link" do
    empty = FormElementShowcase.find_or_create_by!(title: "Gallery-less demo") do |s|
      s.is_active  = false
      s.gender     = 1
      s.rating_int = 1
      s.priority   = 1
      s.priority2  = 1
      s.stars      = 1
      s.scale_int  = 1
      s.scale_val  = 1
    end
    frame = "form_element_showcase_#{empty.id}"

    get form_element_showcase_path(empty, update: frame),
        headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    gallery_frame = @response.body[/<turbo-frame id="#{frame}_gallery">.*?<\/turbo-frame>/m]
    assert gallery_frame, "expected the gallery attribute frame"
    assert_includes gallery_frame, "fi-plus"
  end
end
