# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"
require Dir[Rails.root.join("db/migrate/*_inline_forms_create_join_table_*_role.rb")].first

# Until 8.1.74 down said `drop_table roles_users`, without the colon, and raised.
class ExampleAppRolesJoinTableRollbackTest < ExampleAppIntegrationTestCase
  test "the migration rolls back and runs again" do
    table = User.reflect_on_association(:roles).join_table
    migration = InlineFormsCreateJoinTableUserRole.new

    migration.suppress_messages do
      migration.down
      assert_not migration.table_exists?(table)

      migration.up
      assert migration.table_exists?(table)
    end
  end
end
