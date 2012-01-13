InlineForms::SPECIAL_COLUMN_TYPES[:radio_button]=:string
# radio buttons are strings in this version
def radio_button_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def radio_button_edit(object, attribute)
  attribute_values(object, attribute).each do |n,value|
  radio_button_tag attribute.to_s, value, value == object.send(attribute)
  end
end

def radio_button_update(object, attribute)
  object[attribute.to_s.to_sym] = params[attribute.to_s.to_sym].nil? ? 0 : 1
end

