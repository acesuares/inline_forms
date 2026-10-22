# frozen_string_literal: true

# Lookup with a dropdown_order column: dropdowns offer its records in that
# order (InlineForms::DropdownOrder). Part belongs_to it.
class Phase < ApplicationRecord
  def _presentation
    name
  end
end
