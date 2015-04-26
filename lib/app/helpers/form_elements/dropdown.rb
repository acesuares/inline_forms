# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to

# dropdown
def dropdown_show(object, attribute)
  attr = object.send attribute
  presentation = "_presentation"
  presentation = "_dropdown_presentation" if attr.respond_to? "_dropdown_presentation"
  attribute_value = object.send(attribute).send(presentation) rescue  "<i class='fi-plus'></i>".html_safe
  link_to_inline_edit object, attribute, attribute_value
end

def dropdown_edit(object, attribute)
  object.send('build_' + attribute.to_s) unless object.send(attribute) # we really need this!
  attr = object.send attribute
  presentation = "_presentation"
  presentation = "_dropdown_presentation" if attr.respond_to? "_dropdown_presentation"
  klass = attribute.to_s.singularize.camelcase.constantize
  if cancan_enabled?
    values = klass.accessible_by(current_ability)
  else
    values = klass.all
  end
  values.sort_by! {|v|v.send presentation}
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', presentation, :selected => (object.send(attribute).id rescue nil) )
end

def dropdown_update(object, attribute)
  foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.to_s.foreign_key.to_sym
  object[foreign_key] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_s.foreign_key.to_sym]
end

