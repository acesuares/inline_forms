# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"
require Dir[Rails.root.join("db/migrate/*_seed_example_apartments_and_owners.rb")].first

# The seed's down: apartments.owner_id and phase_id have foreign keys, so the
# apartments are released before the owners and phases go.
class ExampleAppSeedRollbackTest < ExampleAppIntegrationTestCase
  test "down removes the seed and keeps an apartment that is not seeded" do
    seed = SeedExampleApartmentsAndOwners
    owner = Owner.create!(name: seed::OWNERS.first[:name])
    phase = Phase.create!(name: seed::PHASES.first[:name])
    Apartment.create!(name: seed::APARTMENTS.first[:name], owner: owner, phase: phase)
    other = Apartment.create!(name: "Not seeded", owner: owner, phase: phase)

    seed.new.down

    assert_not Owner.exists?(owner.id)
    assert_not Phase.exists?(phase.id)
    assert_not Apartment.exists?(name: seed::APARTMENTS.first[:name])
    assert_nil other.reload.owner_id
    assert_nil other.phase_id
  end
end
