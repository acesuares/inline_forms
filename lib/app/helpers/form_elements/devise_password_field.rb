# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:devise_password_field]=:string

def devise_password_field_show(object, attribute)
  link_to_inline_edit object, attribute, ''
end

def devise_password_field_edit(object, attribute)
  password_field_tag attribute, '', :class => 'input_devise_password_field'
end

def devise_password_field_update(object, attribute)
  object.password = params[attribute.to_sym]
end

