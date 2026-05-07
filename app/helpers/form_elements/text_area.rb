# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:text_area]=:text

def text_area_show(object, attribute)
  if object.send(attribute).blank?
    link_to_inline_edit object, attribute, "<i class='fi-plus'></i>".html_safe, from_callee: __callee__
  else
    link_to_inline_edit object, attribute, object[attribute], from_callee: __callee__
  end
end

def text_area_edit(object, attribute)
  text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
end

def text_area_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end

def text_area_info(object, attribute)
  object[attribute]
end
