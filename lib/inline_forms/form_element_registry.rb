# frozen_string_literal: true

module InlineForms
  module FormElementRegistry
    ENTRIES = {
      audio_field: :string,
      check_box: :boolean,
      check_list: :no_migration,
      color_field: :string,
      date_select: :date,
      decimal_field: :decimal,
      devise_password_field: :string,
      dropdown: :belongs_to,
      dropdown_with_integers: :integer,
      dropdown_with_other: :belongs_to,
      dropdown_with_values: :integer,
      dropdown_with_values_with_stars: :integer,
      file_field: :string,
      header: :string,
      image_field: :string,
      info: :string,
      integer_field: :integer,
      money_field: :integer,
      month_select: :integer,
      month_year_picker: :date,
      multi_image_field: :string,
      plain_text: :text,
      plain_text_area: :text,
      radio_button: :integer,
      rich_text: :no_migration,
      scale_with_integers: :integer,
      scale_with_values: :integer,
      simple_file_field: :string,
      slider_with_values: :integer,
      text_area: :text,
      text_field: :string,
      time_select: :time
    }.freeze

    def self.apply!
      SPECIAL_COLUMN_TYPES.merge!(ENTRIES)
    end
  end
end
