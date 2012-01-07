class MustBeUniqueValidator  < ActiveRecord::Validations::UniquenessValidator

  def error_message
    "is not a unique."
  end

  def help_message
    "Moet uniek zijn (mag niet twee keer voorkomen)."
  end

end
