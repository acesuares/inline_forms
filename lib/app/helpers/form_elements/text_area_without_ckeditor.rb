InlineForms::SPECIAL_COLUMN_TYPES[:text_area_without_ckeditor]=:text

def text_area_without_ckeditor_show(object, attribute)
  link_to_inline_edit object, attribute, object[attribute]
end

def text_area_without_ckeditor_edit(object, attribute)
  text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
end

def text_area_without_ckeditor_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
