# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# One superadmin, user 1, on the screen: the refusals of SingleSuperadmin
# reach the user as messages (inline_forms 8.1.77 shows a refusing
# association callback in the field and a refused destroy in the row).
class ExampleAppSingleSuperadminTest < ExampleAppIntegrationTestCase
  setup do
    @superadmin = example_app_admin_user
    @role = Role.find_by!(name: SingleSuperadmin::SUPERADMIN_ROLE)
    @other = User.create!(name: "Other", email: "other@example.com", locale: @superadmin.locale,
                          password: "other999", password_confirmation: "other999")
  end

  def put_roles(user, role_ids)
    frame = "user_#{user.id}_roles"
    put user_path(user, attribute: "roles", form_element: "check_list", update: frame),
        params: { roles: role_ids.index_with { 1 }.transform_keys(&:to_s) },
        headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }
  end

  test "the signed-in user is user 1, the superadmin" do
    assert_equal SingleSuperadmin::SUPERADMIN_ID, @superadmin.id
    assert @superadmin.superadmin?
  end

  test "a second superadmin is refused with a message" do
    put_roles(@other, [ @role.id ])

    assert_response :success
    assert_includes @response.body, "reserved for the one superadmin"
    assert_not @other.reload.role?(:superadmin)
  end

  test "user 1 cannot drop the role, and the screen says so" do
    put_roles(@superadmin, [])

    assert_response :success
    assert_includes @response.body, "keeps this role"
    assert @superadmin.reload.superadmin?
  end

  test "the superadmin role is not destroyed, the row says why" do
    frame = "role_#{@role.id}"
    delete role_path(@role, update: frame), headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :unprocessable_entity
    assert_includes @response.body, "keeps this role"
    assert Role.exists?(@role.id)
  end

  test "user 1 is not destroyed" do
    frame = "user_#{@superadmin.id}"
    delete user_path(@superadmin, update: frame), headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert User.exists?(@superadmin.id)
  end

  test "another user is destroyed as before" do
    frame = "user_#{@other.id}"
    delete user_path(@other, update: frame), headers: { "Turbo-Frame" => frame, "Accept" => "text/html" }

    assert_response :success
    assert_not User.exists?(@other.id)
  end
end
