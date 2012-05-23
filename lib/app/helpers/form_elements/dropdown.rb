# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to

# dropdown
def dropdown_show(object, attribute)
  attribute_value = object.send(attribute)._presentation rescue  nil
  link_to_inline_edit object, attribute, attribute_value
end

def dropdown_edit(object, attribute)
  object.send('build_' + attribute.to_s) unless object.send(attribute)
  o = object.send(attribute).class.name.constantize
  if cancan_enabled?
    values = o.accessible_by(current_ability).order(o.order_by_clause)
  else
    values = o.order(o.order_by_clause)
  end
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', '_presentation', :selected => object.send(attribute).id)
end

def dropdown_update(object, attribute)
  foreign_key = object.association(attribute.to_sym).reflection.options[:foreign_key] || attribute.to_s.foreign_key.to_sym
  object[foreign_key] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_s.foreign_key.to_sym]
end

