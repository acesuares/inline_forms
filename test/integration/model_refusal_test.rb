# frozen_string_literal: true

require_relative "../integration_test_helper"

# A refusal reaches the user: a model that refuses a destroy, a soft delete or
# restore, or a join row in an association callback; and a dropdown or
# check_list id the field did not offer.
class ModelRefusalTest < InlineFormsIntegrationTestCase
  def member(name = "Ann", **attributes)
    Member.create!(name: name, **attributes)
  end

  def row(member) = "member_#{member.id}"

  def assert_row_refused(member, message)
    assert_response 422
    assert_select "turbo-frame##{row(member)}" do
      assert_select ".inline_forms_row_error li", text: message
      assert_select "a", text: member.name
    end
    refute_includes response.body, "revert"
  end

  def put_field(member, attribute, form_element, values)
    put member_path(member),
      params: { attribute: attribute, form_element: form_element, update: "#{row(member)}_#{attribute}" }.merge(values),
      headers: frame_headers("#{row(member)}_#{attribute}")
  end

  def put_badges(member, *badges)
    put_field(member, "badges", "check_list", badges: badges.to_h { |badge| [ badge.id, "1" ] })
  end

  def create_member(values)
    post members_path, params: { update: "members_list" }.merge(values), headers: frame_headers("members_list")
  end

  # ---- destroy, soft delete, soft restore ------------------------------------

  test "a refused destroy keeps the row and shows why" do
    boss = member("Boss")

    delete member_path(boss, update: row(boss)), headers: frame_headers(row(boss))

    assert_row_refused boss, "The boss stays."
    assert Member.exists?(boss.id)
  end

  test "a destroy refused without a message gets a general one, in nl too" do
    silent = member("Silent")

    delete member_path(silent, update: row(silent)), headers: frame_headers(row(silent))
    assert_row_refused silent, "Could not delete Member."

    I18n.with_locale(:nl) { assert_equal "Kan Member niet verwijderen.", I18n.t("inline_forms.view.destroy_failed", model: "Member") }
  end

  test "a destroy that is not refused still offers undo" do
    ann = member

    delete member_path(ann, update: row(ann)), headers: frame_headers(row(ann))

    assert_response :ok
    assert_includes response.body, "revert"
    refute Member.exists?(ann.id)
  end

  test "a refused soft delete keeps the row as it is and shows why" do
    boss = member("Boss")

    post soft_delete_member_path(boss, update: row(boss)), headers: frame_headers(row(boss))

    assert_row_refused boss, "The boss stays."
    assert_includes response.body, "soft_delete"
    refute_includes response.body, "soft_restore"
    assert Member.find(boss.id).active?
  end

  test "a refused soft restore keeps the row as it is and shows why" do
    ghost = member("Ghost", deleted: :deleted)

    post soft_restore_member_path(ghost, update: row(ghost)), headers: frame_headers(row(ghost))

    assert_row_refused ghost, "Gone for good."
    assert_includes response.body, "soft_restore"
    assert Member.find(ghost.id).deleted?
  end

  test "soft delete and restore that are not refused show the row without a message" do
    ann = member

    post soft_delete_member_path(ann, update: row(ann)), headers: frame_headers(row(ann))
    assert_response :ok
    assert Member.find(ann.id).deleted?

    post soft_restore_member_path(ann, update: row(ann)), headers: frame_headers(row(ann))
    assert_response :ok
    assert_select ".inline_forms_row_error", count: 0
    assert Member.find(ann.id).active?
  end

  # ---- association callbacks -------------------------------------------------

  test "a join row refused in before_add shows the message in the field" do
    silver = Badge.create!(name: "silver")
    gold = Badge.create!(name: "gold")
    ann = member

    put_badges(ann, silver, gold)

    assert_response :ok
    assert_select ".inline_forms_field_error li", text: "No change of gold."
    assert_select "form.edit_form"
    assert_empty Member.find(ann.id).badges
    assert_select "input[type=checkbox][checked]", count: 0
  end

  test "a join row refused in before_remove shows the message and stays" do
    iron = Badge.create!(name: "iron")
    ann = member
    ann.badges << iron

    put_badges(ann)

    assert_select ".inline_forms_field_error li", text: "No change of iron."
    assert_equal [ iron ], Member.find(ann.id).badges
    assert_select "input[type=checkbox][checked]", count: 1
  end

  test "a join row refused on create shows the message in the new form" do
    gold = Badge.create!(name: "gold")

    assert_no_difference -> { Member.count } do
      create_member(name: "Bea", badges: { gold.id => "1" })
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "No change of gold."
    assert_includes response.body, "Could not create Member."
    assert_includes response.body, "Bea"
  end

  # ---- ids that were not offered ---------------------------------------------

  test "a dropdown id that was offered is saved" do
    phase = Phase.create!(name: "intake")
    ann = member

    put_field(ann, "phase", "dropdown", _member: { phase_id: phase.id })

    assert_response :ok
    assert_equal phase, ann.reload.phase
  end

  test "a dropdown id that was not offered is refused" do
    shown = Phase.create!(name: "intake")
    hidden = Phase.create!(name: "hidden")
    Ability.restrictions = -> { cannot :read, Phase, name: "hidden" }
    ann = member(phase: shown)

    [ hidden.id, Phase.maximum(:id) + 1, "nonsense", 10**30 ].each do |id|
      put_field(ann, "phase", "dropdown", _member: { phase_id: id })

      assert_select ".inline_forms_field_error li", text: "Phase is not included in the list"
      assert_equal shown, ann.reload.phase, id.to_s
    end
  end

  test "a malformed dropdown value is refused, not a 500" do
    shown = Phase.create!(name: "intake")
    ann = member(phase: shown)

    put_field(ann, "phase", "dropdown", _member: { phase_id: [ shown.id ] })

    assert_select ".inline_forms_field_error"
    assert_equal shown, ann.reload.phase
  end

  test "the model's own message wins over the general one" do
    top = Phase.create!(name: "top")
    Ability.restrictions = -> { cannot :read, Phase, name: "top" }
    ann = member

    put_field(ann, "phase", "dropdown", _member: { phase_id: top.id })

    assert_select ".inline_forms_field_error li", count: 1, text: "Phase is for the boss"
    assert_nil ann.reload.phase
  end

  test "a message on the foreign key also wins over the general one" do
    closed = Phase.create!(name: "closed")
    Ability.restrictions = -> { cannot :read, Phase, name: "closed" }
    ann = member

    put_field(ann, "phase", "dropdown", _member: { phase_id: closed.id })

    assert_select ".inline_forms_field_error li", count: 1, text: "Phase is closed"
    assert_nil ann.reload.phase
  end

  test "a dropdown option shown disabled is refused, unless the record has it" do
    open_phase = Phase.create!(name: "intake")
    shut = Phase.create!(name: "shut")
    Phase.define_method(:disabled_for_dropdown?) { name == "shut" }
    ann = member(phase: open_phase)

    put_field(ann, "phase", "dropdown", _member: { phase_id: shut.id })

    assert_select ".inline_forms_field_error li", text: "Phase is not included in the list"
    assert_equal open_phase, ann.reload.phase

    bob = member("Bob", phase: shut)
    put_field(bob, "phase", "dropdown", _member: { phase_id: shut.id })

    assert_select ".inline_forms_field_error", count: 0
    assert_equal shut, bob.reload.phase
  ensure
    Phase.remove_method(:disabled_for_dropdown?) if Phase.method_defined?(:disabled_for_dropdown?, false)
  end

  test "the dropdown value a record already has may stay, hidden or not" do
    hidden = Phase.create!(name: "hidden")
    ann = member(phase: hidden)
    Ability.restrictions = -> { cannot :read, Phase, name: "hidden" }

    put_field(ann, "phase", "dropdown", _member: { phase_id: hidden.id })

    assert_select ".inline_forms_field_error", count: 0
    assert_equal hidden, ann.reload.phase
  end

  test "create refuses a dropdown id that was not offered" do
    hidden = Phase.create!(name: "hidden")
    Ability.restrictions = -> { cannot :read, Phase, name: "hidden" }

    assert_no_difference -> { Member.count } do
      create_member(name: "Bea", _member: { phase_id: hidden.id })
    end

    assert_includes response.body, "Phase is not included in the list"
  end

  test "a record with a refused value is not saved by the host either" do
    ann = member
    InlineForms::RefusedValues.add(ann, "phase")

    refute ann.save
    refute ann.validate
    assert_raises(ActiveRecord::RecordInvalid) { ann.save! }
  end

  test "a check list id that was not offered is refused and nothing is written" do
    silver = Badge.create!(name: "silver")
    hidden = Badge.create!(name: "hidden")
    Ability.restrictions = -> { cannot :read, Badge, name: "hidden" }
    ann = member

    put_badges(ann, silver, hidden)

    assert_select ".inline_forms_field_error li", text: "Badges is not included in the list"
    assert_empty Member.find(ann.id).badges
  end

  test "create refuses a check list id that was not offered" do
    hidden = Badge.create!(name: "hidden")
    Ability.restrictions = -> { cannot :read, Badge, name: "hidden" }

    assert_no_difference -> { Member.count } do
      create_member(name: "Bea", badges: { hidden.id => "1" })
    end

    assert_includes response.body, "Badges is not included in the list"
  end

  test "a check list leaves the records it did not offer" do
    silver = Badge.create!(name: "silver")
    bronze = Badge.create!(name: "bronze")
    hidden = Badge.create!(name: "hidden")
    ann = member
    ann.badges = [ silver, hidden ]
    Ability.restrictions = -> { cannot :read, Badge, name: "hidden" }

    put_badges(ann, bronze)

    assert_select ".inline_forms_field_error", count: 0
    assert_equal [ bronze, hidden ], Member.find(ann.id).badges.sort
  end

  # ---- superadmin? -----------------------------------------------------------

  test "the app's superadmin? decides over the role" do
    holder = Struct.new(:boss) do
      def role?(_name) = true
      def superadmin? = boss
    end

    assert InlineForms.superadmin?(holder.new(true))
    refute InlineForms.superadmin?(holder.new(false))
    refute InlineForms.superadmin?(nil)
    assert InlineForms.superadmin?(ApplicationController::DummyUser.new(1, "role only"))
  end

  test "destroy asks superadmin? when the user has it" do
    ann = member
    ApplicationController::DummyUser.define_method(:superadmin?) { false }

    delete member_path(ann, update: row(ann)), headers: frame_headers(row(ann))

    assert_response :forbidden
    assert Member.exists?(ann.id)
  ensure
    ApplicationController::DummyUser.remove_method(:superadmin?) if ApplicationController::DummyUser.method_defined?(:superadmin?, false)
  end
end
