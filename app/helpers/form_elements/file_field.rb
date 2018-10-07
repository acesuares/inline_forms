# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:file_field]=:string

def file_field_show(object, attribute)
  o = object.send(attribute)
  msg = o.to_s
  if o.send(:present?)
    msg = "replace | <a href='#{o.send(:url)}'>#{o.send(:path).gsub(/^.*\//,'')}</a>".html_safe
  end
  link_to_inline_edit object, attribute, msg
end

def file_field_edit(object, attribute)
  file_field_tag attribute, :class => 'input_text_field'
end

def file_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end

