InlineForms::SPECIAL_COLUMN_TYPES[:text_area]=:text

def text_area_show(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def text_area_edit(object, attribute)
  text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
end

def text_area_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
