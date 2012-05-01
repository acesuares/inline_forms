# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:file_field]=:string

def file_field_show(object, attribute)
  link_to_inline_edit object, attribute, 'xxx' #image_tag( object.send(attribute).send(:url) )
end

def file_field_edit(object, attribute)
  file_field_tag attribute, :class => 'input_text_field'
end

def file_field_update(object, attribute)
  object.send(attribute + '=', params[attribute.to_sym])
end

