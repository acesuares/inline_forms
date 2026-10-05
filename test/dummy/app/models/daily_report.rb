# frozen_string_literal: true

# Child of Machine that has no top-level HTML surface: it is only shown
# nested in its machine (like StProject's Dagrapportage inside a Client tab).
class DailyReport < ApplicationRecord
  belongs_to :machine, optional: true

  def self.not_accessible_through_html?
    true
  end

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ]
    ]
  end
end
