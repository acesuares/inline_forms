# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# HABTM helpers on FormElementShowcase:
#   check_list  (locales)          -- editable multi-select
#   info_list   (locales_display)  -- read-only mirror of the same association
#                                     via `alias_method :locales_display, :locales`
#
# Locale (not Role) is the showcase association because Role is reserved
# for the auth Member/User model in this example app; reusing it on
# FormElementShowcase would coincidentally share rows with roles_users
# which is confusing.
class ExampleAppShowcaseLocalesAssociationsTest < ExampleAppIntegrationTestCase
  setup do
    @en = Locale.find_or_create_by!(name: "en") { |l| l.title = "English"    }
    @nl = Locale.find_or_create_by!(name: "nl") { |l| l.title = "Nederlands" }
    @de = Locale.find_or_create_by!(name: "de") { |l| l.title = "Deutsch"    }

    @showcase = FormElementShowcase.find_or_create_by!(title: "Locales demo")
    @showcase.locales.clear
  end

  def field_frame(attr)
    "form_element_showcase_#{@showcase.id}_#{attr}"
  end

  def field_headers(attr)
    { "Turbo-Frame" => field_frame(attr), "Accept" => "text/html" }
  end

  test "check_list locales toggles the HABTM association" do
    frame = field_frame(:locales)

    # Initially empty; PUT with two locales checked.
    put form_element_showcase_path(
      @showcase,
      attribute: "locales",
      form_element: "check_list",
      update: frame
    ), params: { locales: { @en.id.to_s => 1, @de.id.to_s => 1 } }, headers: field_headers(:locales)

    assert_response :success
    assert_equal [@en.id, @de.id].sort, @showcase.reload.locale_ids.sort

    # PUT again with only one locale; the missing one is uncoupled.
    put form_element_showcase_path(
      @showcase,
      attribute: "locales",
      form_element: "check_list",
      update: frame
    ), params: { locales: { @nl.id.to_s => 1 } }, headers: field_headers(:locales)

    assert_response :success
    assert_equal [@nl.id], @showcase.reload.locale_ids
  end

  test "info_list locales_display mirrors the locales association read-only" do
    @showcase.locales << @en unless @showcase.locales.where(id: @en.id).exists?

    row_frame = "form_element_showcase_#{@showcase.id}"
    get form_element_showcase_path(@showcase, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success
    info_frame = field_frame(:locales_display)
    assert_includes @response.body, %(<turbo-frame id="#{info_frame}">),
      "expected info_list frame for :locales_display"
    # info_list_show renders each item's `_presentation`. Locale's is `title`.
    assert_match(/<turbo-frame id="#{info_frame}">.*#{Regexp.escape(@en.title)}/m, @response.body,
      "expected #{@en.title.inspect} inside the locales_display info_list frame")
  end

  test "info_list locales_display empty-state renders the -- placeholder" do
    @showcase.locales.clear

    row_frame = "form_element_showcase_#{@showcase.id}"
    get form_element_showcase_path(@showcase, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success
    info_frame = field_frame(:locales_display)
    assert_match(/<turbo-frame id="#{info_frame}">[^<]*<div class='row [^']+'>--<\/div>/m, @response.body,
      "expected empty `--` placeholder inside the locales_display frame")
  end
end
