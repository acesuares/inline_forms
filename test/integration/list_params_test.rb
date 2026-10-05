# frozen_string_literal: true

require_relative "../integration_test_helper"

# Request params that end up in a list's markup.
#
# * parent_class / parent_id: _list built the nested frame as
#   `raw "<turbo-frame id=\"#{update_span}\" …>"` with update_span made from
#   params[:parent_id], and constantized params[:parent_class]; nothing found
#   the parent before the render, so a crafted parent_id was reflected into
#   the page. The controller now refuses malformed parent params (400) in
#   index/new/create/show, and the frame is built with tag.turbo_frame.
# * pagination: the page links carry every filter of the query string, not
#   just `search`.
#
# Part and DailyReport belong to Machine; Widget is a top-level list
# (per_page 7, see ApplicationRecord).
class ListParamsTest < InlineFormsIntegrationTestCase
  PAYLOAD = %("><img src=x onerror=alert(1)>)

  setup do
    @machine = Machine.create!(name: "Press")
    @part = Part.create!(name: "Gear", machine: @machine)
    @list_frame = "machine_#{@machine.id}_parts_list"
  end

  def assert_refused_without_payload
    assert_response :bad_request
    assert controller.instance_variable_defined?(:@_authorized),
      "the refusal runs after authorization (check_authorization stays satisfied)"
    refute_includes response.body, "<img"
  end

  def nested(parent_id: @machine.id, parent_class: "Machine", update: @list_frame)
    { parent_class: parent_class, parent_id: parent_id, update: update, ul_needed: 1 }
  end

  # ---- malformed parent params --------------------------------------------

  test "a crafted parent_id on the nested list is a 400 and never rendered" do
    get parts_path(nested(parent_id: PAYLOAD, update: "x")), headers: frame_headers("x")
    assert_refused_without_payload
  end

  test "a crafted parent_id is refused on a full-page visit too" do
    get parts_path(nested(parent_id: PAYLOAD, update: "x"))
    assert_refused_without_payload
  end

  test "a parent_class that is not an association of the model is a 400" do
    %w[Widget Kernel machine Machines ActiveRecord::Base].each do |parent_class|
      get parts_path(nested(parent_class: parent_class)), headers: frame_headers(@list_frame)
      assert_response :bad_request, "parent_class=#{parent_class}"
    end
  end

  test "a non-integer parent_id is a 400, with or without parent_class" do
    [ "1 OR 1=1", "-1", "1.5", "" ].each do |parent_id|
      get parts_path(nested(parent_id: parent_id)), headers: frame_headers(@list_frame)
      assert_response :bad_request, "parent_id=#{parent_id.inspect}"
    end
    get parts_path(parent_id: PAYLOAD, update: "x")
    assert_refused_without_payload
  end

  test "new with crafted parent params is a 400" do
    get new_part_path(nested(parent_id: PAYLOAD, update: "machine_#{@machine.id}_parts")),
        headers: frame_headers("machine_#{@machine.id}_parts")
    assert_refused_without_payload

    get new_part_path(nested(parent_class: "Widget", update: "machine_#{@machine.id}_parts")),
        headers: frame_headers("machine_#{@machine.id}_parts")
    assert_response :bad_request
  end

  test "create with crafted parent params is a 400 and creates nothing" do
    frame = "machine_#{@machine.id}_parts"
    assert_no_difference -> { Part.count } do
      post parts_path(nested(parent_id: PAYLOAD, update: frame)), params: { name: "Bolt" }, headers: frame_headers(frame)
      assert_refused_without_payload
      post parts_path(nested(parent_class: "Widget", update: frame)), params: { name: "Bolt" }, headers: frame_headers(frame)
      assert_response :bad_request
    end
  end

  test "show with a crafted parent_id is a 400" do
    row = "machine_#{@machine.id}_part_#{@part.id}"
    get part_path(@part, update: row, parent_class: "Machine", parent_id: PAYLOAD), headers: frame_headers(row)
    assert_refused_without_payload
  end

  # ---- well-formed nested lists still work --------------------------------

  test "a well-formed nested list renders its frame and rows" do
    get parts_path(nested), headers: frame_headers(@list_frame)

    assert_response :success
    assert_includes response.body, %(<turbo-frame id="#{@list_frame}" class="list_container">)
    assert_includes response.body, "Gear"
  end

  test "well-formed nested new and create still work" do
    frame = "machine_#{@machine.id}_parts"
    get new_part_path(nested(update: frame)), headers: frame_headers(frame)
    assert_response :success

    assert_difference -> { @machine.parts.count }, 1 do
      post parts_path(nested(update: frame)), params: { name: "Bolt" }, headers: frame_headers(frame)
    end
    assert_response :success
  end

  test "the nested list of a not_accessible_through_html? child still renders" do
    DailyReport.create!(name: "Monday", machine: @machine)
    frame = "machine_#{@machine.id}_daily_reports_list"
    get daily_reports_path(parent_class: "Machine", parent_id: @machine.id, update: frame, ul_needed: 1),
        headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, "Monday"
  end

  test "the list frame id is attribute-escaped by the partial itself" do
    html = PartsController.render(
      partial: "inline_forms/list",
      assigns: { Klass: Part, parent_class: "Machine", parent_id: PAYLOAD, ul_needed: "1",
                 objects: Part.where(id: @part.id).paginate(page: 1) }
    )

    refute_includes html, "<img"
    assert_includes html, %(<turbo-frame id="machine_&quot;&gt;&lt;img src=x onerror=alert(1)&gt;_parts_list" class="list_container">)
  end

  # ---- pagination keeps the filters ---------------------------------------

  test "page links of a filtered list carry every filter" do
    9.times { |i| Widget.create!(name: "Match #{i}") }
    Widget.create!(name: "Other")

    get widgets_path(search: "Match", sorteer: "name", first_name: "An", group: { id: 3 }, status: { id: 4 },
                     update: "widgets_list"),
        headers: frame_headers("widgets_list")

    assert_response :success
    page_link = response.body[/href="([^"]*page=2[^"]*)"/, 1]
    assert page_link, "a link to page 2"
    query = Rack::Utils.parse_nested_query(URI.parse(CGI.unescapeHTML(page_link)).query)
    assert_equal "Match", query["search"]
    assert_equal "name", query["sorteer"]
    assert_equal "An", query["first_name"]
    assert_equal({ "id" => "3" }, query["group"])
    assert_equal({ "id" => "4" }, query["status"])
    assert_equal "widgets_list", query["update"]
    assert_equal "2", query["page"]

    get CGI.unescapeHTML(page_link), headers: frame_headers("widgets_list")
    assert_response :success
    back = response.body[/href="([^"]*page=1[^"]*)"/, 1]
    assert back, "a link back to page 1"
    back_query = Rack::Utils.parse_nested_query(URI.parse(CGI.unescapeHTML(back)).query)
    assert_equal "Match", back_query["search"]
    assert_equal({ "id" => "3" }, back_query["group"])
    refute_includes response.body, "Other"
  end

  test "page links of a list rendered after create keep the request's filters" do
    9.times { |i| Machine.create!(name: "Match #{i}") }

    post machines_path(update: "machines_list", search: "Match", sorteer: "name"),
         params: { name: "Match 9" }, headers: frame_headers("machines_list")

    assert_response :success
    page_link = response.body[/href="([^"]*page=2[^"]*)"/, 1]
    assert page_link, "a link to page 2"
    query = Rack::Utils.parse_nested_query(URI.parse(CGI.unescapeHTML(page_link)).query)
    assert_equal "Match", query["search"]
    assert_equal "name", query["sorteer"]
  end

  # url_for options in the query string must not shape the page links.
  # will_paginate leaves out script_name / original_script_name; merging
  # request.query_parameters into the links bypassed that, so the payload
  # became the start of every page link's href, and controller= raised.
  test "url options in the query string never reach the page links" do
    9.times { |i| Widget.create!(name: "W #{i}") }

    %w[script_name original_script_name].each do |option|
      get "/widgets?update=widgets_list&#{option}=javascript:alert(1)//", headers: frame_headers("widgets_list")
      assert_response :success
      page_link = response.body[/href="([^"]*page=2[^"]*)"/, 1]
      assert page_link, "a link to page 2"
      assert page_link.start_with?("/widgets?"), "#{option} shaped the page link: #{page_link}"
      refute_includes response.body, "javascript:alert"
    end

    get "/widgets?update=widgets_list&controller=widgets_x", headers: frame_headers("widgets_list")
    assert_response :success
    assert_match %r{href="/widgets\?[^"]*page=2}, response.body
  end
end
