# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:image_field]=:string

def image_field_show(object, attribute)
#  if object.send(attribute).send(:present?)
#    title = "Full Size: #{object.send(attribute).send(:url)}.<br />" +  image_tag(object.send(attribute).send(:palm).send(:url))
#  else
#    title = ''
#  end
  link_to_inline_edit object, attribute, object.send(attribute).send(:present?) ? image_tag(object.send(attribute).send(:palm).send(:url)) : object.send(attribute).to_s
end

def image_field_edit(object, attribute)
  file_field_tag attribute, :class => 'input_text_field'
end

def image_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end

