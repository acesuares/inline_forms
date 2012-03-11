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
  end

  def validate_each(record, attribute, value)
    values = attribute_values(record, attribute)
    if values.assoc(value).nil?
      record.errors[attribute] << (options[:message] || error_message )
    end
  end

  protected
  def attribute_values(object, attribute)
    # if we have a range 1..6  will result in [[0,1],[1,2],[2,3],...,[5,6]]
    # or range -3..3 will result in [[0,-3],[1,-2],[2,-1],...,[6,3]]
    # if we have an array ['a','d','b'] will result in [[0,'a'],[2,'b'],[1,'d']] (sorted on value)
    # if we have a hash { 0=>'a', 2=>'b', 3=>'d' } will result in [[0,'a'],[2,'b'],[3,'d']] (it will keep the index and sort on the index)
    # TODO work this out better!
    # 2012-01-23 Use Cases
    # [ :sex , "sex", :radio_button, { 1 => 'f', 2 => 'm' } ],
    # in this case we want the attribute in the database to be 1 or 2. From that attribute, we need to find the value.
    # using an array, won't work, since [ 'v', 'm' ][1] would be 'm' in stead of 'v'
    # so values should be a hash. BUT since we don't have sorted hashes (ruby 1,.8.7), the order of the values in the edit screen will be random.
    # so we DO need an array, and look up by index.
    # [[1,'v'],[2,'m]] and then use #assoc:
    # assoc(obj) → new_ary or nil
    # Searches through an array whose elements are also arrays comparing obj with the first element of each contained array using obj.==.
    # Returns the first contained array that matches (that is, the first associated array), or nil if no match is found. See also Array#rassoc.
    # like value=values.assoc(attribute_from_database)[1] (the [1] is needed since the result of #assoc = [1,'v'] and we need the 'v')
    # I feel it's ugly but it works.

    attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list # if we do this as a form_element, @inline.. is nil!!!
    values = attributes.assoc(attribute.to_sym)[3]
    raise "No Values defined in #{@Klass}, #{attribute}" if values.nil?
    if values.is_a?(Hash)
      temp = Array.new
      values.to_a.each do |k,v|
        temp << [ k, v ]
      end
      values = temp.sort {|a,b| a[0]<=>b[0]}
    else
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, values.to_a[i] ]
      end
      values = temp.sort {|a,b| a[1]<=>b[1]}
    end
    values
  end
end
