# frozen_string_literal: true

class Badge < ApplicationRecord
  def _presentation
    name
  end

  def <=>(other)
    name <=> other.name
  end
end
