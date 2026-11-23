# frozen_string_literal: true

# A model that refuses: see test/integration/model_refusal_test.rb.
class Member < ApplicationRecord
  include InlineForms::SoftDeletable

  class Refused < ActiveRecord::RecordInvalid; end

  belongs_to :phase, optional: true
  has_and_belongs_to_many :badges,
    before_add: ->(member, badge) { member.refuse_badge!(badge, "gold") },
    before_remove: ->(member, badge) { member.refuse_badge!(badge, "iron") }

  # Search box with suggestions (test/integration/suggestions_test.rb).
  inline_forms_search_on :name, suggest: { match: :word, limit: 3 }

  enum :deleted, { active: 1, deleted: 2 }

  attr_accessor :deleter

  validate { errors.add(:base, "The boss stays.") if name == "Boss" && deleted? }
  validate { errors.add(:base, "Gone for good.") if name == "Ghost" && active? && persisted? }
  validate { errors.add(:phase, "is for the boss") if phase&.name == "top" && name != "Boss" }
  validate { errors.add(:phase_id, "is closed") if phase&.name == "closed" }
  before_destroy { throw :abort if name == "Silent" }
  before_destroy do
    if name == "Boss"
      errors.add(:base, "The boss stays.")
      throw :abort
    end
  end

  def refuse_badge!(badge, name)
    return unless badge.name == name

    errors.add(:base, "No change of #{name}.")
    raise Refused, self
  end

  def _presentation
    name
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ],
      [ :phase, :dropdown ],
      [ :badges, :check_list ]
    ]
  end
end
