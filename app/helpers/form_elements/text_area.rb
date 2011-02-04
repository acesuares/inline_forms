module InlineFormsHelper
    InlineForms::MIGRATION_TYPE_CONVERSION_LIST[:text_area]=:text
  # text_area
  def text_area_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def text_area_edit(object, attribute, values)
    text_area_tag attribute, object[attribute], :class => 'field_text_area'
  end
  def text_area_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end
end
