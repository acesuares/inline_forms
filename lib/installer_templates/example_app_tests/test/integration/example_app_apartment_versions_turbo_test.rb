# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

class ExampleAppApartmentVersionsTurboTest < ExampleAppIntegrationTestCase
  setup do
    @apartment = Apartment.first || Apartment.create!(name: "Versions Turbo", title: "T")
    @versions_frame = "apartment_#{@apartment.id}_versions"
    @headers = { "Turbo-Frame" => @versions_frame, "Accept" => "text/html" }
  end

  test "versions list opens inside matching turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame), headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    assert_includes @response.body, "Changeset"
    refute_includes @response.body, 'data-remote="true"'
  end

  test "versions list close returns panel header inside turbo-frame" do
    get list_versions_apartment_path(@apartment, update: @versions_frame, close: true),
        headers: @headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{@versions_frame}">)
    refute_includes @response.body, "Changeset"
  end

  test "expanded row versions open link uses Turbo not UJS remote" do
    row_frame = "apartment_#{@apartment.id}"
    get apartment_path(@apartment, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }
    assert_response :success
    assert_select "turbo-frame##{@versions_frame} a[data-turbo='true'][data-turbo-frame='#{@versions_frame}']", minimum: 1
    refute_select "turbo-frame##{@versions_frame} a[data-remote='true']"
  end

  test "restore link in versions list requests turbo-stream (nested versions frame)" do
    apt = Apartment.create!(name: "Stream Link", title: "T")
    apt.update!(title: "T2")
    vf = "apartment_#{apt.id}_versions"
    get list_versions_apartment_path(apt, update: vf),
        headers: { "Turbo-Frame" => vf, "Accept" => "text/html" }
    assert_response :success
    assert_match(/data-turbo-stream="true"/, @response.body,
      "restore from inside …_versions must use turbo-stream to avoid Turbo-Frame mismatch")
  end

  test "revert from versions list closes row via turbo-stream when Turbo-Frame is versions" do
    apt = Apartment.create!(name: "Versions Stream Revert", title: "Before")
    apt.update!(title: "After")
    row_frame = "apartment_#{apt.id}"
    versions_frame = "#{row_frame}_versions"
    version = apt.versions.where(event: "update").order(:id).last
    assert version, "expected an update version to revert"

    post revert_apartment_path(version.id, update: row_frame),
         headers: {
           "Turbo-Frame" => versions_frame,
           "Accept" => "text/vnd.turbo-stream.html"
         }
    assert_response :success
    assert_includes @response.body, %(action="replace")
    assert_includes @response.body, %(target="#{row_frame}")
    assert_includes @response.body, %(target="#{versions_frame}")
    assert_equal "Before", apt.reload.title
  end

  test "revert from versions list closes row via Turbo POST on row frame" do
    apt = Apartment.create!(name: "Versions Revert", title: "Before")
    apt.update!(title: "After")
    row_frame = "apartment_#{apt.id}"
    row_headers = { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    version = apt.versions.where(event: "update").order(:id).last
    assert version, "expected an update version to revert"

    post revert_apartment_path(version.id, update: row_frame), headers: row_headers
    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{row_frame}">)
    refute_includes @response.body, "object_presentation"
    assert_equal "Before", apt.reload.title
  end
end
