InlineForms::SPECIAL_COLUMN_TYPES[:radio_button]=:integer
# radio buttons are integers in this version
# us like this:
#   [ :sex , "gender", :radio_button, { 1 => 'male', 2 => 'female' } ],

def radio_button_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def radio_button_edit(object, attribute)
  out ='<ul class="radio_list">'
  attribute_values(object, attribute).each do |n,value|
    out << '<li>'
    out << radio_button_tag(attribute.to_s, value, value == object.send(attribute))
    out << value
    out << '</li>'
  end
  out << '</ul>'
  raw out
end

def radio_button_update(object, attribute)
  object[attribute.to_s.to_sym] = params[attribute.to_s.to_sym].nil? ? 0 : 1
end

