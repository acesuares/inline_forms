module InlineFormsHelper
    InlineForms::MIGRATION_TYPE_CONVERSION_LIST[:dropdown_with_values]=:integer
  # dropdown_with_values
  def dropdown_with_values_show(object, attribute, values)
    link_to_inline_edit object, attribute, values[object.send(attribute)], values
  end
  def dropdown_with_values_edit(object, attribute, values)
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
  end
  def dropdown_with_values_update(object, attribute, values)
    object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
  end
end

