module InlineFormsHelper
    InlineForms::SPECIAL_COLUMN_TYPES[:range]=:integer
  # range
  def range_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def range_edit(object, attribute, values)
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'to_i', 'to_s', :selected => object.send(attribute))
  end
  def range_update(object, attribute, values)
    object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
  end
end

