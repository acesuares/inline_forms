# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# pdf_link links to /<attribute>/:id and /<attribute>/:id.pdf; the app owns
# both routes. The example app's are ShowcaseReportsController.
class ExampleAppShowcasePdfLinkTest < ExampleAppIntegrationTestCase
  setup { @showcase = FormElementShowcase.create!(title: "Report demo") }

  test "the show page has a preview and a pdf link that leave the turbo frame" do
    get form_element_showcase_path(@showcase)

    assert_response :success
    assert_select %(a.pdf_preview[href="/report/#{@showcase.id}"][data-turbo="false"][target="_blank"])
    assert_select %(a.pdf_open[href="/report/#{@showcase.id}.pdf"][data-turbo="false"])
    assert_select %(a.pdf_open[target]), false
  end

  test "the new form renders with the pdf_link row" do
    frame = "form_element_showcases_list"
    get new_form_element_showcase_path(update: frame), headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
  end

  test "preview renders the record" do
    get "/report/#{@showcase.id}"

    assert_response :success
    assert_select "#showcase_report"
    assert_includes response.body, "Report demo"
  end

  test "pdf downloads a PDF" do
    get "/report/#{@showcase.id}.pdf"

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Aattachment/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-")
  end

  test "guests get neither" do
    sign_out example_app_admin_user

    get "/report/#{@showcase.id}"
    assert_response :redirect

    get "/report/#{@showcase.id}.pdf"
    assert_response :unauthorized
  end
end
