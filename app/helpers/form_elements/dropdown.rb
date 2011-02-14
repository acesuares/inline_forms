module InlineFormsHelper
  InlineForms::SPECIAL_MIGRATION_TYPES[:dropdown]=:integer
  # dropdown
  def dropdown_show(object, attribute, values)
    attribute_value = object.send(attribute)._presentation rescue  nil
    link_to_inline_edit object, attribute, attribute_value, nil
  end
  def dropdown_edit(object, attribute, values)
    object.send('build_' + attribute.to_s) unless object.send(attribute)
    values = object.send(attribute).class.name.constantize.find(:all) # TODO bring order!
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', '_presentation', :selected => object.send(attribute).id)
  end
  def dropdown_update(object, attribute, values)
    object[attribute.to_s.foreign_key.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_s.foreign_key.to_sym]
  end
end

