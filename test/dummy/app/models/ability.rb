# frozen_string_literal: true

# Grants everything (the generated superadmin branch). A test narrows it by
# setting Ability.restrictions to a block of `cannot` rules, evaluated after
# the grant so they win; InlineFormsIntegrationTestCase resets it.
class Ability
  include CanCan::Ability

  cattr_accessor :restrictions

  def initialize(_user)
    can :manage, :all
    instance_exec(&restrictions) if restrictions
  end
end
