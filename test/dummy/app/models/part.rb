# frozen_string_literal: true

# Child of Machine (see machine.rb); shaped like the example app's Photo.
class Part < ApplicationRecord
  belongs_to :machine, optional: true

  def _presentation
    "#{name}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :name, :text_field ]
    ]
  end
end
