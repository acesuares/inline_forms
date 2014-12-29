# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:dropdown_with_values_with_stars]=:integer

# dropdown_with_values_with_stars
def dropdown_with_values_with_stars_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, (object[attribute].nil? || object[attribute] == 0) ? "<i class='fi-plus'></i>".html_safe : image_tag(object[attribute].to_s + 'stars.png')
end
def dropdown_with_values_with_stars_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
end
def dropdown_with_values_with_stars_update(object, attribute)
  object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
end
