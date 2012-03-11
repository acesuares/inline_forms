# == usage:
# in your model, add:
#  validates :id_number, must_be_present => true, is_a_curacao_id_number => true;
class IsACuracaoIdNumberValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if value =~ /^[0-9]{10}$/
      year  = value[0..3].to_i
      month = value[4..5].to_i
      day   = value[6..7].to_i
      number= value[8..9].to_i
      begin
        DateTime.civil(year, month, day)
      rescue ArgumentError
        record.errors[attribute] << (options[:message] || "is geen geldig ID nummer voor Curacao." )
      end
    else
      record.errors[attribute] << (options[:message] || "moet bestaan uit tien cijfers (bijvoorbeeld 1983040812)." )
    end
  end

end