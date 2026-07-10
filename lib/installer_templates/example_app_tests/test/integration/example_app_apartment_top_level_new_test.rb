# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Step 4: top-level `/apartments` list, +new, cancel, and create use Turbo Frames
# (`<turbo-frame id="apartments_list">`) instead of UJS + new.js.erb / list.js.erb.
class ExampleAppApartmentTopLevelNewTest < ExampleAppIntegrationTestCase
  setup do
    @frame = "apartments_list"
    @frame_headers = { "Turbo-Frame" => @frame, "Accept" => "text/html" }
    @apartment = Apartment.find_or_create_by!(name: "Top Level List Apt") do |a|
      a.title = "Top level list seed"
    end
  end

  test "top-level apartments index wraps list in turbo-frame" do
    get apartments_path
    assert_response :success
    assert_match(
      %r{<turbo-frame[^>]+id="#{Regexp.escape(@frame)}"[^>]*class="list_container"},
      @response.body
    )
    refute_match(
      %r{<div[^>]+id="#{Regexp.escape(@frame)}"[^>]*class="list_container"},
      @response.body,
      "list root must be turbo-frame, not legacy div"
    )
  end

  test "top-level + new link uses Turbo not UJS remote" do
    get apartments_path
    assert_response :success
    assert_match(
      %r{<a [^>]*class="button new_button"[^>]*data-turbo="true"[^>]*data-turbo-frame="#{Regexp.escape(@frame)}"[^>]*href="/apartments/new\?update=apartments_list"},
      @response.body
    )
    refute_match(
      %r{<a [^>]*class="button new_button"[^>]*data-remote="true"},
      @response.body
    )
  end

  test "top-level new returns new form inside matching turbo-frame" do
    get new_apartment_path(update: @frame), headers: @frame_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame}">)
    assert_includes @response.body, 'name="name"'
    assert_includes @response.body, 'class="edit_form"'
    refute_includes @response.content_type.to_s, "javascript"
  end

  test "top-level cancel returns list inside matching turbo-frame" do
    get apartments_path(update: @frame, ul_needed: true), headers: @frame_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame}")
    assert_includes @response.body, "<turbo-frame id=\"apartment_"
  end

  test "top-level create via Turbo persists and returns the list frame" do
    name = "TopLevelNewApt-#{SecureRandom.hex(4)}"
    assert_difference("Apartment.count", 1) do
      post apartments_path(update: @frame),
        params: { name: name, title: "Top level new test" },
        headers: @frame_headers
    end
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@frame}">)
    assert_includes @response.body, name
  end

  # "Open after create": Apartment has photos:associated, so a turbo-stream
  # create response refreshes the list AND opens the new row, landing the user
  # where the photos panel (only available on a persisted record) is usable.
  test "top-level create with turbo-stream accept opens the new row" do
    name = "AAA-OpenAfterCreate-#{SecureRandom.hex(4)}"
    assert_difference("Apartment.count", 1) do
      post apartments_path(update: @frame),
        params: { name: name, title: "Open after create test" },
        headers: { "Turbo-Frame" => @frame,
                   "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type

    apartment = Apartment.find_by!(name: name)
    assert_includes @response.body,
      %(<turbo-stream action="replace" target="#{@frame}">)
    assert_includes @response.body,
      %(<turbo-stream action="replace" target="apartment_#{apartment.id}">)
    assert_includes @response.body,
      %(id="apartment_#{apartment.id}_photos_list_auto_header")
    assert_match(
      %r{/photos/new\?[^"]*parent_id=#{apartment.id}},
      @response.body,
      "expected the photos panel's new link for the created apartment"
    )
  end
end
