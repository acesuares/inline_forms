# frozen_string_literal: true

# Models StProject's Client/Attachment: file bytes stored in a binary column
# that is excluded from PaperTrail (`skip:`), filename kept versioned. Reverting
# an unrelated edit must not touch `data`. See
# test/integration/revert_skipped_columns_test.rb.
#
# Not an ApplicationRecord: that already calls has_paper_trail, which PaperTrail
# allows only once per hierarchy. StProject likewise declares it per model, so
# this repeats the rest of the ApplicationRecord host contract inline.
class Dossier < ActiveRecord::Base
  include InlineForms::Searchable

  has_paper_trail on: [ :create, :update, :destroy ], skip: [ :data ]

  attr_writer :inline_forms_attribute_list

  self.per_page = 7

  scope :inline_forms_list, -> { order(:name, :id) }

  validates :name, presence: true

  def self.not_accessible_through_html?
    false
  end

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ],
      [ :data_filename, :info ]
    ]
  end
end
