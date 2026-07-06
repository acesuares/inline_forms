# frozen_string_literal: true

# Lookup model for Widget's dropdown_with_other (kind / kind_other).
class Kind < ApplicationRecord
  def _presentation
    name
  end
end
