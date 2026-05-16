# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# 7.5.2: top-level Apartment +new+ / +cancel+ / +create+ keep the legacy UJS
# (+remote: true+) contract. 7.5.1 emitted +data-turbo-frame="apartments_list"+
# on the +"+ new"+ link, but the index page wraps the list in a plain
# +<div id="apartments_list">+ (not a +<turbo-frame>+) -- so:
#
# * +cancel+ / +create+ targeted a frame the page did not have, and Turbo
#   logged "Content missing" and dropped the response;
# * the +"+ new"+ click itself either fell back to a full-page navigation or
#   landed in that broken state.
#
# Wrapping the top-level list in a real +<turbo-frame>+ regresses layout
# (the frame collapses inside +position: absolute+ +#outer_container+), so
# the fix keeps top-level behind UJS: +link_to_new_record+ omits Turbo data
# attributes when no +parent_class+ is provided, and +new.js.erb+ /
# +list.js.erb+ swap +#apartments_list+ contents in place.
class ExampleAppApartmentTopLevelNewTest < ExampleAppIntegrationTestCase
  setup do
    @frame = "apartments_list"
  end

  test "top-level apartments index keeps the legacy <div> wrapper (no <turbo-frame> for the list root)" do
    get apartments_path
    assert_response :success
    assert_match(
      %r{<div[^>]+class="list_container"[^>]+id="#{Regexp.escape(@frame)}"},
      @response.body,
      "top-level list must stay a <div id=\"apartments_list\"> for UJS swaps; " \
      "wrapping in a <turbo-frame> at this position breaks layout"
    )
    refute_match(
      %r{<turbo-frame\s+id="#{Regexp.escape(@frame)}"},
      @response.body,
      "top-level list root should NOT be a <turbo-frame> -- doing so regresses " \
      "layout (frame collapses under fixed top bars) and orphans cancel/create"
    )
  end

  test "top-level + new link uses UJS (data-remote), not Turbo" do
    get apartments_path
    assert_response :success
    assert_match(
      %r{<a [^>]*class="button new_button"[^>]*data-remote="true"[^>]*href="/apartments/new\?update=apartments_list"},
      @response.body,
      "top-level + must POST via UJS (no <turbo-frame> on the page to target); " \
      "data-turbo* on this link causes 'Content missing' on cancel/create"
    )
    refute_match(
      %r{<a [^>]*class="button new_button"[^>]*data-turbo-frame="#{Regexp.escape(@frame)}"},
      @response.body,
      "top-level + must NOT carry data-turbo-frame=apartments_list (no matching frame)"
    )
  end

  test "top-level new returns JS that swaps #apartments_list with the form (UJS)" do
    get new_apartment_path(update: @frame), xhr: true
    assert_response :success
    assert_includes @response.content_type, "javascript",
      "UJS XHR must hit format.js"
    assert_match(
      %r{\$\('#apartments_list'\)\.html\(},
      @response.body,
      "UJS new.js.erb must swap #apartments_list with the rendered form"
    )
    assert_includes @response.body, 'name=\"name\"'
    assert_includes @response.body, 'class=\"edit_form\"'
  end

  test "top-level cancel returns JS that swaps #apartments_list back to the list (UJS)" do
    get apartments_path(update: @frame, ul_needed: true), xhr: true
    assert_response :success
    assert_includes @response.content_type, "javascript",
      "UJS XHR must hit format.js"
    assert_match(
      %r{\$\('#apartments_list'\)\.html\(},
      @response.body,
      "UJS list.js.erb must swap #apartments_list back to the list"
    )
  end

  test "top-level create via UJS persists and returns the list swap" do
    name = "TopLevelNewApt-#{SecureRandom.hex(4)}"
    assert_difference("Apartment.count", 1) do
      post apartments_path(update: @frame),
        params: { name: name, title: "Top level new test" },
        xhr: true
    end
    assert_response :success
    assert_includes @response.content_type, "javascript"
    assert_match(
      %r{\$\('#apartments_list'\)\.html\(},
      @response.body
    )
    assert_includes @response.body, name,
      "expected the newly-created Apartment to appear in the swapped list"
  end
end
