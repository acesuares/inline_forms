# frozen_string_literal: true

require_relative "../integration_test_helper"

# Covers the pending-migration gate: an attribute_list row whose column does
# not exist yet (the inline_forms_addto window between the model edit and
# `rails db:migrate`) must render a read-only placeholder and be skipped on
# write, instead of 500ing on the missing column. Gizmo's list references
# :pending_note, which has no column on the gizmos table (see
# test/integration_test_helper.rb and test/dummy/app/models/gizmo.rb).
class PendingMigrationGateTest < InlineFormsIntegrationTestCase
  setup do
    @gizmo = Gizmo.create!(name: "Gadget")
  end

  test "predicate flags a phantom column and only that" do
    g = @gizmo
    # phantom scalar column -> pending
    assert InlineForms.attribute_pending_migration?(g, :pending_note, :text_field)
    # real column -> not pending
    refute InlineForms.attribute_pending_migration?(g, :name, :text_field)
    # header is a label, never gated
    refute InlineForms.attribute_pending_migration?(g, :section, :header)
    # info bound to a real column
    refute InlineForms.attribute_pending_migration?(g, :created_at, :info)
    # relation dropdown backed by a missing foreign key -> pending
    assert InlineForms.attribute_pending_migration?(g, :vendor, :dropdown)
    # no-column elements are never gated
    refute InlineForms.attribute_pending_migration?(g, :parts, :has_many)
    refute InlineForms.attribute_pending_migration?(g, :body, :rich_text)
    refute InlineForms.attribute_pending_migration?(g, :report, :pdf_link)
    # exempt virtual-backed elements (column name != attribute)
    refute InlineForms.attribute_pending_migration?(g, :amount, :money_field)
  end

  test "row show renders a pending placeholder and does not raise" do
    frame = "gizmo_#{@gizmo.id}"
    get gizmo_path(@gizmo, update: frame), headers: frame_headers(frame)

    assert_response :success
    assert_includes response.body, "pending migration"
    # the real field still renders its own edit frame
    assert_includes response.body, %(<turbo-frame id="gizmo_#{@gizmo.id}_name">)
    # the phantom field is NOT rendered as an editable field frame
    refute_includes response.body, %(<turbo-frame id="gizmo_#{@gizmo.id}_pending_note">)
  end

  test "new form renders a pending placeholder instead of an input" do
    get new_gizmo_path(update: "gizmos_list"), headers: frame_headers("gizmos_list")

    assert_response :success
    assert_includes response.body, "pending migration"
    refute_includes response.body, %(name="pending_note")
  end

  test "create skips the pending column and still saves" do
    assert_difference -> { Gizmo.count }, +1 do
      post gizmos_path(update: "gizmos_list"),
           params: { name: "Fresh", pending_note: "ignored — no column yet" },
           headers: frame_headers("gizmos_list")
    end
    assert_response :success
    assert Gizmo.exists?(name: "Fresh")
  end

  test "forced update of a pending field is refused, not a 500" do
    frame = "gizmo_#{@gizmo.id}_pending_note"
    put gizmo_path(@gizmo, attribute: "pending_note", form_element: "text_field",
                   update: frame),
        params: { pending_note: "x" }, headers: frame_headers(frame)

    assert_response :unprocessable_entity
    assert_includes response.body, "pending migration"
  end
end
