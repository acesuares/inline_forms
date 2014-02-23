# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:integer_field]=:integer

def integer_field_show(object, attribute)
  link_to_inline_edit object, attribute, object[attribute].nil? ? "<i class='fi-plus'></i>".html_safe : object[attribute]
end

def integer_field_edit(object, attribute)
  number_field_tag attribute, (object.send attribute.to_sym), :class => 'input_integer_field'  # for abide: , :required => true
end

def integer_field_update(object, attribute)
  object.send :write_attribute, attribute.to_sym, params[attribute.to_sym]
end

