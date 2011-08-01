# FIXME not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def infoadmin_show(object, attribute)
  object.send(attribute)._presentation rescue  ''
end

def infoadmin_edit(object, attribute)
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

def infoadmin_update(object, attribute)
  object[attribute.to_s.foreign_key.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_s.foreign_key.to_sym]
end

