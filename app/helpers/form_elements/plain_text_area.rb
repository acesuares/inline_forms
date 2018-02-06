# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:plain_text_area]=:text

def plain_text_area_show(object, attribute)
  link_to_inline_edit object, attribute, (object[attribute].nil? || object[attribute].empty?) ? "<i class='fi-plus'></i>".html_safe : object[attribute]
end

def plain_text_area_edit(object, attribute)
  text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
end

def plain_text_area_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
