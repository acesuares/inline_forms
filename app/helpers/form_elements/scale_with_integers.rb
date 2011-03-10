module InlineFormsHelper
    InlineForms::SPECIAL_COLUMN_TYPES[:scale_with_integers]=:integer
  # scale_with_integers generates a sacle
  # with the given list of integers as options
  #
  # values must be a Range or a one-dimensional array of Integers
  def scale_with_integers_show(object, attribute, values)
    unless values.is_a?(Hash)
      options = Array.new
      values.to_a.each_index do |i|
        options << [ i.to_s, values.to_a[i] ]
      end
      values = Hash[ *options.flatten ]
    end
    link_to_inline_edit object, attribute, values[object.send(attribute).to_s], values
  end
  def scale_with_integers_edit(object, attribute, values)
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    values = values.sort {|a,b| a[1].to_i<=>b[1].to_i}
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
  end
  def scale_with_integers_update(object, attribute, values)
    object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
  end
end

