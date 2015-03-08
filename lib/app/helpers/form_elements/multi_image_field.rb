# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:multi_image_field]=:string

def multi_image_field_show(object, attribute)
  o = object.send(attribute)
  msg = "<i class='fi-plus'></i>".html_safe
  if o.send(:present?)
    if o.respond_to? :palm
      msg = image_tag(o.send(:palm).send(:url))
    else
      msg = image_tag(o.send(:url))
    end
  end
  link_to_inline_edit object, attribute, msg
end

def multi_image_field_edit(object, attribute)
  file_field_tag attribute, multiple: true, class: 'input_text_field multi_image_field'
end

def multi_image_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end

