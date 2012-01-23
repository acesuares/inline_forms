InlineForms::SPECIAL_COLUMN_TYPES[:radio_button]=:integer
# radio buttons are integers in this version
# us like this:
#   [ :sex , "gender", :radio_button, { 1 => 'male', 2 => 'female' } ],

def radio_button_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, values.assoc(object.send(attribute))[1] #TODO code for values.assoc(object.send(attribute)) = nil
end

def radio_button_edit(object, attribute)
  out ='<ul class="radio_list">'
  values = attribute_values(object, attribute)
  values.each do |key,value|
    out << '<li>'
    out << radio_button_tag(attribute.to_s, key, key == object.send(attribute))
    out << value
    out << '</li>'
  end
  out << '</ul>'
  raw out
end

def radio_button_update(object, attribute)
  object[attribute.to_s.to_sym] = params[attribute.to_s.to_sym]
end

