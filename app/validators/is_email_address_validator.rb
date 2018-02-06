# -*- encoding : binary -*-
# == usage:
# in your model, add:
#  validates :email, :presence => true, :is_email_address => true;
# taken from http://lindsaar.net/2010/1/31/validates_rails_3_awesome_is_true
# (It's probably a fake regex but hey, it looks legit.)
class IsEmailAddressValidator < ActiveModel::EachValidator
  EmailAddress = begin
    qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
    dtext = '[^\\x0d\\x5b-\\x5d\\x80-\\xff]'
    atom = '[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-' +
      '\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+'
    quoted_pair = '\\x5c[\\x00-\\x7f]'
    domain_literal = "\\x5b(?:#{dtext}|#{quoted_pair})*\\x5d"
    quoted_string = "\\x22(?:#{qtext}|#{quoted_pair})*\\x22"
    domain_ref = atom
    sub_domain = "(?:#{domain_ref}|#{domain_literal})"
    word = "(?:#{atom}|#{quoted_string})"
    domain = "#{sub_domain}(?:\\x2e#{sub_domain})*"
    local_part = "#{word}(?:\\x2e#{word})*"
    addr_spec = "#{local_part}\\x40#{domain}"
    pattern = /\A#{addr_spec}\z/
  end

  def error_message
    "is not a valid email address."
  end
  
  def validate_each(record, attribute, value)
    unless value =~ EmailAddress
      record.errors[attribute] << (options[:message] || error_message )
    end
  end

end
