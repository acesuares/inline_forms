# frozen_string_literal: true

require "test_helper"

# One superadmin, user 1 (app/models/concerns/single_superadmin.rb and the
# end of app/models/ability.rb).
class SingleSuperadminTest < ActiveSupport::TestCase
  include TheSuperadmin

  setup do
    @superadmin = the_superadmin
    @role = Role.find_by!(name: SingleSuperadmin::SUPERADMIN_ROLE)
    @other = User.create!(name: "Other", email: "other@example.com", locale: @superadmin.locale,
                          password: "other999", password_confirmation: "other999")
  end

  test "only user 1 holding the role is the superadmin" do
    assert @superadmin.superadmin?
    assert_not @other.superadmin?
    assert_not User.new.superadmin?
  end

  test "role? asks by name and is false without roles" do
    assert @superadmin.role?(:superadmin)
    assert_not @other.role?(:superadmin)
    assert_not @other.role?(:no_such_role)
  end

  test "giving the role to another user is refused, from either side" do
    error = assert_raises(SingleSuperadmin::Refused) { @other.role_ids = [ @role.id ] }
    assert_includes error.record.errors.full_messages.join, "reserved"
    assert_raises(SingleSuperadmin::Refused) { @role.users << @other }
    assert_not @other.reload.roles.include?(@role)
  end

  test "a new user is refused the role when it is given" do
    assert_raises(SingleSuperadmin::Refused) do
      User.new(name: "New", email: "new@example.com", locale: @superadmin.locale,
               password: "new99999", password_confirmation: "new99999", roles: [ @role ])
    end
    assert_not User.exists?(email: "new@example.com")
  end

  test "a user who holds the role by a database edit is not saved" do
    give_role_by_database_edit(@other)
    assert_not @other.reload.valid?
    assert_includes @other.errors.full_messages.join, "reserved"
  end

  test "user 1 keeps the role, from either side" do
    assert_raises(SingleSuperadmin::Refused) { @superadmin.role_ids = [] }
    assert_raises(SingleSuperadmin::Refused) { @role.users.delete(@superadmin) }
    assert @superadmin.reload.superadmin?
  end

  test "user 1 is not destroyed" do
    assert_equal false, @superadmin.destroy
    assert User.exists?(SingleSuperadmin::SUPERADMIN_ID)
    assert_not_empty @superadmin.errors[:base]
  end

  test "the superadmin role keeps its name and is not destroyed" do
    assert_not @role.update(name: "boss")
    assert_equal false, @role.reload.destroy
    assert Role.exists?(name: SingleSuperadmin::SUPERADMIN_ROLE)
  end

  test "another holder of the role, by a database edit, gets nothing" do
    give_role_by_database_edit(@other)
    ability = Ability.new(@other.reload)
    assert @other.role?(:superadmin)
    assert_not @other.superadmin?
    assert ability.cannot?(:update, @superadmin)
    assert ability.cannot?(:read, @role)
    assert ability.cannot?(:manage, User)
  end

  test "the superadmin manages everything but destroying user 1" do
    ability = Ability.new(@superadmin)
    assert ability.can?(:update, @superadmin)
    assert ability.can?(:update, @role)
    assert ability.can?(:destroy, @other)
    assert ability.cannot?(:destroy, @superadmin)
  end

  private

  def give_role_by_database_edit(user)
    roles = User.reflect_on_association(:roles)
    User.connection.execute("INSERT INTO #{roles.join_table} (role_id, #{roles.foreign_key}) VALUES (#{@role.id}, #{user.id})")
  end
end
