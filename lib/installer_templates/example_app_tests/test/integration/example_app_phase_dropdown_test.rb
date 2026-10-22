# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Phase (inline_forms 8.1.59): a lookup with a dropdown_order column. The
# apartment's phase dropdown follows dropdown_order ('---' first, then the
# phases in process order), not id order and not the alphabetical list order
# of /phases. See InlineForms::DropdownOrder.
class ExampleAppPhaseDropdownTest < ExampleAppIntegrationTestCase
  PHASES = { "decision" => 20, "admittance" => 30, "---" => 0, "helprequest" => 10 }.freeze

  setup do
    PHASES.each do |name, position|
      Phase.find_or_create_by!(name: name) { |phase| phase.dropdown_order = position }
    end
    @apartment = Apartment.find_or_create_by!(name: "Phase Apt") { |a| a.title = "Phase Title" }
  end

  test "the apartment phase dropdown follows dropdown_order" do
    frame = "apartment_#{@apartment.id}_phase"
    get edit_apartment_path(@apartment, attribute: "phase", form_element: "dropdown", update: frame),
        headers: { "Turbo-Frame" => frame }

    assert_response :success
    options = @response.body.scan(%r{<option(?: [^>]*)?>([^<]*)</option>}).flatten
    assert_equal [ "---", "helprequest", "decision", "admittance" ], options
  end

  test "choosing a phase in the dropdown saves it" do
    frame = "apartment_#{@apartment.id}_phase"
    decision = Phase.find_by!(name: "decision")

    put apartment_path(@apartment, attribute: "phase", form_element: "dropdown", update: frame),
        params: { _apartment: { phase_id: decision.id } }, headers: { "Turbo-Frame" => frame }

    assert_response :success
    assert_equal decision, @apartment.reload.phase
  end

  test "the phases list stays in its own (alphabetical) list order" do
    get phases_path

    assert_response :success
    positions = %w[admittance decision helprequest].map { |name| @response.body.index(">#{name}<") }
    assert positions.all?, "every phase is listed"
    assert_equal positions.sort, positions
  end
end
