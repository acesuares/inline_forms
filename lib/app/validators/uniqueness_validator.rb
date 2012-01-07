class ActiveRecord::Validations::UniquenessValidator
  def error_message
    "is not unique."
  end

  def help_message
    "Needs to be unique."
  end

end
