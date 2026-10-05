# frozen_string_literal: true

require_relative "../integration_test_helper"

# Every HTML request the engine decides not to serve gets an explicit answer:
# a top-level list of a not_accessible_through_html? model is a 404, a
# new/create/show/destroy/revert without the frame context the gem needs is a
# 400. Before, the format.html block rendered nothing (or was not registered),
# so Rails fell through to implicit rendering: ActionController::
# MissingExactTemplate (500; StProject's GET /dagrapportages) or UnknownFormat
# (406). create, destroy and revert also refuse before writing anything.
#
# DailyReport is the not_accessible_through_html? child of Machine; Machine is
# a normal (accessible) model.
class HtmlRefusalTest < InlineFormsIntegrationTestCase
  setup do
    @machine = Machine.create!(name: "Press")
    @report = DailyReport.create!(name: "Monday", machine: @machine)
    @list_frame = "machine_#{@machine.id}_daily_reports"
    @row_frame = "machine_#{@machine.id}_daily_report_#{@report.id}"
  end

  def nested_params(update = @list_frame)
    { update: update, parent_class: "Machine", parent_id: @machine.id }
  end

  def stream_headers(frame_id)
    frame_headers(frame_id).merge("Accept" => "text/vnd.turbo-stream.html")
  end

  # The refusal ran after authorization, so CanCan's check_authorization (an
  # after_action in host apps) is satisfied.
  def assert_refused(status)
    assert_response status
    assert controller.instance_variable_defined?(:@_authorized),
      "the refused request must still count as authorized (check_authorization)"
  end

  # ---- not_accessible_through_html? model, top level -----------------------

  test "the top-level list of a not_accessible_through_html? model is a 404" do
    get daily_reports_path
    assert_refused :not_found
  end

  test "show without a nested row frame is a 400" do
    get daily_report_path(@report)
    assert_refused :bad_request
  end

  test "new without update and parent_class is a 400" do
    get new_daily_report_path
    assert_refused :bad_request
  end

  test "create without update and parent_class is a 400 and creates nothing" do
    assert_no_difference -> { DailyReport.count } do
      post daily_reports_path, params: { name: "Tuesday" }
    end
    assert_refused :bad_request
  end

  test "destroy without a nested row frame is a 400 and keeps the record" do
    delete daily_report_path(@report)
    assert_refused :bad_request
    assert DailyReport.exists?(@report.id)
  end

  test "revert without a nested row frame is a 400 and changes nothing" do
    @report.update!(name: "Changed")
    version = @report.versions.where(event: "update").last

    post revert_daily_report_path(version.id, update: "daily_report_#{@report.id}"),
         headers: stream_headers("daily_report_#{@report.id}")
    assert_refused :bad_request
    assert_equal "Changed", @report.reload.name
  end

  # ---- the nested forms still work (regression guard) ----------------------

  test "the nested list, new form, create, row and destroy still render" do
    get daily_reports_path(nested_params), headers: frame_headers(@list_frame)
    assert_response :success
    assert_includes response.body, "Monday"

    get new_daily_report_path(nested_params), headers: frame_headers(@list_frame)
    assert_response :success

    assert_difference -> { DailyReport.count }, +1 do
      post daily_reports_path(nested_params), params: { name: "Tuesday" }, headers: frame_headers(@list_frame)
    end
    assert_response :success
    assert_equal @machine.id, DailyReport.find_by!(name: "Tuesday").machine_id

    get daily_report_path(@report, update: @row_frame), headers: frame_headers(@row_frame)
    assert_response :success
    assert_includes response.body, %(<turbo-frame id="#{@row_frame}">)

    delete daily_report_path(@report, update: @row_frame), headers: frame_headers(@row_frame)
    assert_response :success
    refute DailyReport.exists?(@report.id)
  end

  test "a nested revert still restores the record" do
    @report.update!(name: "Changed")
    version = @report.versions.where(event: "update").last

    post revert_daily_report_path(version.id, update: @row_frame), headers: stream_headers(@row_frame)
    assert_response :success
    assert_equal "Monday", @report.reload.name
  end

  # ---- accessible model ------------------------------------------------------

  test "an accessible model's list and row still render" do
    get machines_path
    assert_response :success
    assert_includes response.body, "Press"

    get machine_path(@machine)
    assert_response :success
  end

  test "an accessible model's new and create without update are a 400; nothing is created" do
    get new_machine_path
    assert_refused :bad_request

    assert_no_difference -> { Machine.count } do
      post machines_path, params: { name: "Lathe" }
    end
    assert_refused :bad_request
  end

  test "destroy by a user who may not hard-destroy is a 403 and keeps the record" do
    ApplicationController.dummy_user_superadmin = false
    frame = "machine_#{@machine.id}"

    delete machine_path(@machine, update: frame), headers: frame_headers(frame)
    assert_refused :forbidden
    assert Machine.exists?(@machine.id)
  end

  # ---- file slots ------------------------------------------------------------

  test "a refused file-slot request still counts as authorized" do
    document = Document.create!(title: "Plan")
    frame = "document_#{document.id}_filename"

    post remove_file_document_path(document, attribute: "title", update: frame), headers: stream_headers(frame)
    assert_refused :bad_request
  end
end
