# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:rich_text]=:no_migration

def rich_text_show(object, attribute)
  value = object.respond_to?(attribute) ? object.public_send(attribute) : nil
  text = value.respond_to?(:to_plain_text) ? value.to_plain_text : value.to_s
  display_value = text.blank? ? "<i class='fi-plus'></i>".html_safe : value.to_s.html_safe
  link_to_inline_edit object, attribute, display_value, from_callee: __callee__
end

def rich_text_edit(object, attribute)
  value = object.respond_to?(attribute) ? object.public_send(attribute) : nil
  rich_text_area_tag attribute, value.to_s, :class => 'attribute_text_area'
end

def rich_text_update(object, attribute)
  object.public_send("#{attribute}=", params[attribute.to_sym])
end

def rich_text_info(object, attribute)
  value = object.respond_to?(attribute) ? object.public_send(attribute) : nil
  value.to_s
end
