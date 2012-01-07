class IsUniqueValidator  < ActiveModel::EachValidator
  delegate :new, :setup, :validate_each, :to => ActiveRecord::Validations::UniquenessValidator

  def error_message
    "is not a unique."
  end

  def help_message
    "Needs to be unique."
  end

end
