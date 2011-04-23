InlineForms::SPECIAL_COLUMN_TYPES[:image]=:image

# image via paperclip
def image_show(object, attribute)
  link_to_inline_image_edit object, attribute
end

def image_edit(object, attribute)
  file_attribute object.class.to_s.underscore, attribute
end

def image_update(object, attribute)
  object.send(attribute+'=',values)
end
