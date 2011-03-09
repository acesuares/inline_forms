module InlineFormsHelper
  InlineForms::SPECIAL_COLUMN_TYPES[:image]=:image
  # image via paperclip
  def image_show(object, attribute, values)
    link_to_inline_image_edit object, attribute
  end
  def image_edit(object, attribute, values)
    file_field object.class.to_s.downcase, attribute
  end
  def image_update(object, attribute, values)
    object.send(attribute+'=',values)
  end
end
