# frozen_string_literal: true

# Exercises one representative of each form-element family the integration
# tests cover; shaped exactly like a `rails g inline_forms` model.
class Widget < ApplicationRecord
  belongs_to :kind, optional: true

  validates :name, presence: true

  scope :inline_forms_list, -> { order(:name, :id) }
  scope :inline_forms_search, ->(q) { where("name LIKE ?", "%#{q}%") }

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ],
      [ :notes, :plain_text_area ],
      [ :released_on, :date_select ],
      [ :meeting_at, :time_select ],
      [ :start_month, :month_year_picker ],
      [ :priority, :dropdown_with_values, { 1 => "low", 2 => "mid", 3 => "high" } ],
      [ :active, :check_box, { 0 => "no", 1 => "yes" } ],
      [ :kind, :dropdown_with_other ],
      [ :rating, :slider_with_values, { 1 => "one", 2 => "two", 3 => "three", 4 => "four", 5 => "five" } ],
      # simple_file_field's values entry names the host download route method
      # (attribute_values(...)[0][1]); only used when a file is present.
      [ :manual, :simple_file_field, { 0 => "download" } ],
      [ :accent, :color_field ],
      [ :report, :pdf_link ]
    ]
  end

  def <=>(other)
    name <=> other.name
  end
end
