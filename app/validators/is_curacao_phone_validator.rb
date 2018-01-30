# -*- encoding : utf-8 -*-
# == usage:
# in your model, add:
#  validates :email, :presence => true, :is_email_address => true;
# taken from http://lindsaar.net/2010/1/31/validates_rails_3_awesome_is_true
# (It's probably a fake regex but hey, it looks legit.)
class IsCuracaoPhoneValidator < ActiveModel::EachValidator

  def error_message
    "is geen geldig Curaçao telefoon nummer."
  end

  def help_message
    "Telefoonnummer moet 7 cijfers zijn, bijvoorbeeld 6781256."
  end

  def validate_each(record, attribute, value)
    unless value =~ /[4-8][0-9]{6}/
      record.errors[attribute] << (options[:message] || error_message )
    end
  end

end
