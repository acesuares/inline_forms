# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# /owners/:id ships two Turbo sub-tabs (`naw`, `apartments`). The custom
# OwnersController#show picks one of two attribute subsets driven by
# `params[:tab]`, sets `set_tab` so the active tab is highlighted, and
# renders inside the row `<turbo-frame id="owner_<id>">` so a tab click
# is a single partial swap. `name` deliberately appears on both tabs.
class ExampleAppOwnerTabsTest < ExampleAppIntegrationTestCase
  setup do
    apartment = Apartment.first ||
                Apartment.create!(name: "Owner Tabs Apt", title: "T")
    @owner = Owner.create!(
      name: "Tabs Owner #{SecureRandom.hex(3)}",
      birthdate: Date.new(1980, 1, 2),
      address: "1 Test St",
      city: "Willemstad",
      country: "Curaçao"
    )
    apartment.update!(owner: @owner)
    @row_frame = "owner_#{@owner.id}"
    @row_headers = { "Turbo-Frame" => @row_frame, "Accept" => "text/html" }
  end

  test "owners index wraps each row in a turbo-frame" do
    get owners_path
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
  end

  test "row open renders the tab strip + the default NAW tab" do
    get owner_path(@owner, update: @row_frame), headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)

    # Tab strip is present, both labels are visible.
    assert_select "ul#owner_#{@owner.id}_tabs", count: 1
    assert_select "ul#owner_#{@owner.id}_tabs li", count: 2

    # NAW is the active tab on the default request; the active tab is a
    # `<span>`, the inactive tab is a real `<a>` carrying
    # `data-turbo-frame="<row_frame>"`.
    assert_select "ul#owner_#{@owner.id}_tabs li.current span", text: /Naw/i, count: 1
    assert_select "ul#owner_#{@owner.id}_tabs a[data-turbo-frame=?]",
                  @row_frame, minimum: 1

    # NAW attribute subset is rendered; the Apartments-tab-only field
    # (the :apartments associated list, keyed by its own auto-header id)
    # is NOT. The generic `associated_auto_header` class still appears on
    # the Versions panel header, so assert on the specific apartments id.
    assert_includes @response.body, "birthdate"
    assert_includes @response.body, "country"
    refute_includes @response.body,
                    %(id="owner_#{@owner.id}_apartments_list_auto_header")
  end

  test "tab=apartments shows the apartments associated list and shared name" do
    get owner_path(@owner, update: @row_frame, tab: "apartments"),
        headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)

    # Active tab is now "apartments".
    assert_select "ul#owner_#{@owner.id}_tabs li.current span",
                  text: /Apartments/i, count: 1

    # The `name` field is on BOTH tabs (shared field by design).
    assert_includes @response.body, "name"

    # The `:apartments :associated` row is rendered.
    assert_includes @response.body,
                    %(id="owner_#{@owner.id}_apartments_list_auto_header")

    # NAW-only fields (e.g. birthdate, country) are NOT rendered on this tab.
    refute_match(/data-attribute="birthdate"/, @response.body)
    refute_match(/data-attribute="country"/,   @response.body)
  end

  test "unknown tab parameter falls back to NAW" do
    get owner_path(@owner, update: @row_frame, tab: "bogus"),
        headers: @row_headers
    assert_response :success
    assert_select "ul#owner_#{@owner.id}_tabs li.current span",
                  text: /Naw/i, count: 1
  end

  test "close link still uses stock controller flow (not tabbed render)" do
    get owner_path(@owner, update: @row_frame, close: true),
        headers: @row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@row_frame}">)
    # _close renders the collapsed row -- no tab strip, no presentation panel.
    refute_select "ul#owner_#{@owner.id}_tabs"
    refute_includes @response.body, "object_presentation"
  end

  test "tab links carry data-turbo-frame on the anchor (TurboTabsBuilder)" do
    get owner_path(@owner, update: @row_frame), headers: @row_headers
    assert_response :success

    # The inactive tab's link must carry data-turbo-frame pointing at the
    # row frame -- this is exactly what TurboTabsBuilder threads through
    # to <a> via link_options. Upstream tabs_on_rails 3.0 could only
    # annotate the <li>, so this assertion would fail without it.
    assert_select(
      "ul#owner_#{@owner.id}_tabs li:not(.current) a[data-turbo-frame=?]",
      @row_frame,
      minimum: 1
    )
    refute_select "ul#owner_#{@owner.id}_tabs a[data-remote='true']"
  end

  test "TurboTabsBuilder leaves the active tab as a span (no link)" do
    get owner_path(@owner, update: @row_frame, tab: "apartments"),
        headers: @row_headers
    assert_response :success
    # The active tab is rendered via link_to_unless so the anchor is
    # replaced by the inner <span>; there should be no <a> inside li.current.
    refute_select "ul#owner_#{@owner.id}_tabs li.current a"
    assert_select  "ul#owner_#{@owner.id}_tabs li.current span", count: 1
  end
end
