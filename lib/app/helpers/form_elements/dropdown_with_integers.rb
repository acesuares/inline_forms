# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:dropdown_with_integers]=:integer

# dropdown_with_integers generates a dropdown menu
# with the given list of integers as options
#
# values must be a Range or a one-dimensional array of Integers
def dropdown_with_integers_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, values[object.send(attribute)][1]
end

def dropdown_with_integers_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
end

def dropdown_with_integers_update(object, attribute)
  object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
end
