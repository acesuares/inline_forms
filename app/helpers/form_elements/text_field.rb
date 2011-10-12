InlineForms::SPECIAL_COLUMN_TYPES[:text_field]=:string

def text_field_show(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def text_field_edit(object, attribute)
  text_field_tag attribute, object[attribute], :class => 'input_text_field'
end

def text_field_update(object, attribute)
  object[attribute.to_s.to_sym] = params[attribute.to_sym]
end

