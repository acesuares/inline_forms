# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:text_field]=:string

def text_field_show(object, attribute)
  link_to_inline_edit object, attribute, object[attribute].blank? ? "<i class='fi-plus'></i>".html_safe : object[attribute]
end

def text_field_edit(object, attribute)
  text_field_tag attribute, (object.send attribute.to_sym), :class => 'input_text_field'  # for abide: , :required => true
end

def text_field_update(object, attribute)
  object.send :write_attribute, attribute.to_sym, params[attribute.to_sym]
end

def text_field_info(object, attribute)
  object[attribute]
end
