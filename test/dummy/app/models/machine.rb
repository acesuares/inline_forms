# frozen_string_literal: true

# Parent with an :associated (has_many) panel, shaped like the example app's
# Apartment (photos:has_many photos:associated). Exercises the
# open-after-create flow (InlineFormsController#render_created_row_open_streams).
class Machine < ApplicationRecord
  has_many :parts

  validates :name, presence: true

  scope :inline_forms_list, -> { order(:name, :id) }

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ],
      [ :parts, :associated ]
    ]
  end
end
