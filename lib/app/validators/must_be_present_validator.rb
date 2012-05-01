# -*- encoding : utf-8 -*-
class MustBePresentValidator  < ActiveModel::Validations::PresenceValidator

  def error_message
    "is not a unique."
  end

  def help_message
    "Verplicht veld (moet ingevuld worden)."
  end

end
