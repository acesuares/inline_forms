# -*- encoding : utf-8 -*-
class MustBeUniqueValidator  < ActiveRecord::Validations::UniquenessValidator

  def error_message
    "is not a unique."
  end


end
