# frozen_string_literal: true

require_relative "../integration_test_helper"

# dropdown_edit sorts its options by presentation; the sort_by result used to
# be discarded, so the options came out in id order.
class DropdownTest < InlineFormsIntegrationTestCase
  test "dropdown_edit lists the options sorted by presentation" do
    %w[Zeta Alpha Mu].each { |name| Machine.create!(name: name) }
    part = Part.create!(name: "Gear")

    get machines_path
    html = controller.view_context.dropdown_edit(part, :machine)

    assert_equal %w[Alpha Mu Zeta], html.scan(%r{<option value="\d+">([^<]*)</option>}).flatten
  end
end
