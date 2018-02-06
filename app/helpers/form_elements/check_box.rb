# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:check_box]=:boolean
# boolean, bit unaptly named check_box
def check_box_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, values[object.send(attribute) ? 1 : 0 ][1]
end

def check_box_edit(object, attribute)
  check_box_tag attribute.to_s, 1, object.send(attribute)
end

def check_box_update(object, attribute)
  object[attribute.to_s.to_sym] = params[attribute.to_s.to_sym].nil? ? 0 : 1
end

