module InlineFormsHelper
  InlineForms::MIGRATION_TYPE_CONVERSION_LIST[:text_field]=:string
  # text
  def text_field_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def text_field_edit(object, attribute, values)
    text_field_tag attribute, object[attribute], :class => 'input_text_field'
  end
  def text_field_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end
end

