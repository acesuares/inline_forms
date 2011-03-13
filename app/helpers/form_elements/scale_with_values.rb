InlineForms::SPECIAL_COLUMN_TYPES[:scale_with_values]=:integer

# scale_with_values generates a scale
# with the given list of values as options
#
# values must be a hash { integer => string, ... } or an one-dimensional array of strings
def scale_with_values_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, values[object.send(attribute)]
end

def scale_with_values_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
end

def scale_with_values_update(object, attribute)
  object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
end

