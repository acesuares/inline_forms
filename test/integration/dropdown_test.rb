# frozen_string_literal: true

require_relative "../integration_test_helper"

# Order of the records table-backed form elements offer
# (InlineForms::DropdownOrder): the model's inline_forms_dropdown_order, else
# a dropdown_order column, else inline_forms_list, else database order.
class DropdownTest < InlineFormsIntegrationTestCase
  teardown do
    [ Phase, Machine, Kind, Part ].each do |klass|
      klass.remove_instance_variable(:@inline_forms_dropdown_order) if klass.instance_variable_defined?(:@inline_forms_dropdown_order)
    end
  end

  def view
    get machines_path
    controller.view_context
  end

  def option_texts(html)
    html.scan(%r{<option(?: [^>]*)?>([^<]*)</option>}).flatten
  end

  def create_phases
    Phase.create!(name: "admittance", dropdown_order: 30)
    Phase.create!(name: "nieuw")
    Phase.create!(name: "decision", dropdown_order: 20)
    Phase.create!(name: "---", dropdown_order: 0)
    Phase.create!(name: "helprequest", dropdown_order: 10)
  end

  test "a dropdown_order column orders the dropdown, NULLs last" do
    create_phases

    html = view.dropdown_edit(Part.create!(name: "Gear"), :phase)

    assert_equal [ "---", "helprequest", "decision", "admittance", "nieuw" ], option_texts(html)
  end

  test "the model's declared direction applies to the dropdown_order column" do
    create_phases
    Phase.inline_forms_dropdown_order :dropdown_order, :desc

    html = view.dropdown_edit(Part.create!(name: "Gear"), :phase)

    assert_equal [ "admittance", "decision", "helprequest", "---", "nieuw" ], option_texts(html)
  end

  test "a declared column wins over the dropdown_order column" do
    create_phases
    Phase.inline_forms_dropdown_order :name, :desc

    html = view.dropdown_edit(Part.create!(name: "Gear"), :phase)

    assert_equal [ "nieuw", "helprequest", "decision", "admittance", "---" ], option_texts(html)
  end

  test "without a declaration or column, the list order applies" do
    %w[Zeta Alpha Mu].each { |name| Machine.create!(name: name) } # inline_forms_list: order(:name, :id)

    html = view.dropdown_edit(Part.create!(name: "Gear"), :machine)

    assert_equal %w[Alpha Mu Zeta], option_texts(html)
  end

  test "ties on the declared column break on id" do
    first = Phase.create!(name: "same", dropdown_order: 5)
    second = Phase.create!(name: "same", dropdown_order: 5)

    assert_equal [ first.id, second.id ], InlineForms::DropdownOrder.apply(Phase.all).map(&:id)
  end

  test "without anything declared, records come in database order" do
    %w[Zeta Alpha].each { |name| Kind.create!(name: name) } # inline_forms_list: all

    assert_equal %w[Zeta Alpha], InlineForms::DropdownOrder.apply(Kind.all).map(&:name)
  end

  test "dropdown_with_other offers its datalist in the dropdown order" do
    %w[Zeta Alpha Mu].each { |name| Kind.create!(name: name) }
    Kind.inline_forms_dropdown_order :name

    html = view.dropdown_with_other_edit(Widget.create!(name: "W"), :kind)

    assert_equal %w[Alpha Mu Zeta], html.scan(/<option value="([^"]*)">/).flatten
  end

  test "check_list lists its records in the dropdown order" do
    machine = Machine.create!(name: "Press")
    %w[Bolt Nut Axle].each { |name| Part.create!(name: name) }
    Part.inline_forms_dropdown_order :name, :desc

    html = view.check_list_edit(machine, :parts)

    assert_equal %w[Nut Bolt Axle], html.scan(%r{<label for=[^>]*>([^<]*)</label>}).flatten.reject(&:empty?)
  end

  test "an unknown direction or column is refused" do
    assert_raises(ArgumentError) { Phase.inline_forms_dropdown_order :name, :up }

    Phase.inline_forms_dropdown_order :position
    assert_raises(ArgumentError) { InlineForms::DropdownOrder.apply(Phase.all).to_a }
  end
end
