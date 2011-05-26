InlineForms::SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to

# dropdown
def dropdown_show(object, attribute)
  attribute_value = object.send(attribute)._presentation rescue  nil
  link_to_inline_edit object, attribute, attribute_value
end

def dropdown_edit(object, attribute)
  object.send('build_' + attribute.to_s) unless object.send(attribute)
  if cancan_enabled?
    values = object.send(attribute).class.name.constantize.accessible_by(current_ability).order(@Klass.order_by_clause)
  else
    values = object.send(attribute).class.name.constantize.order(@Klass.order_by_clause)
  end
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', '_presentation', :selected => object.send(attribute).id)
end

def dropdown_update(object, attribute)
  object[attribute.to_s.foreign_key.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_s.foreign_key.to_sym]
end

