InlineForms::SPECIAL_COLUMN_TYPES[:image_field]=:string

def image_field_show(object, attribute)
  link_to_inline_edit object, attribute, image_tag( object.send(attribute).send(:url) )
end

def image_field_edit(object, attribute)
  file_field_tag attribute, :class => 'input_text_field'
end

def image_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end

