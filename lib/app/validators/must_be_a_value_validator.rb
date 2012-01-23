# == usage:
# in your model, add:
#  validates :sex, :must_be_a_value => true;
# 
#  this checks against the objects attribute_values
class MustBeAValueValidator < ActiveModel::EachValidator

  def error_message
    "is geen geldige keuze."
  end

  def help_message
    "U dient een keuze te maken."
  end

  def validate_each(record, attribute, value)
    values = attribute_values(record, attribute)
    if values.assoc(value).nil?
      record.errors[attribute] << (options[:message] || error_message )
    end
  end

end
