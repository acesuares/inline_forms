InlineForms::SPECIAL_COLUMN_TYPES[:date_select]=:date

# date
def date_select_show(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def date_select_edit(object, attribute)
  css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute
  out = text_field_tag attribute, object[attribute], :id => css_id
  out << '<SCRIPT>'.html_safe
  out << "$(function() { ".html_safe
  out << '$("#'.html_safe + css_id.html_safe + '").datepicker();'.html_safe
  out << '});'.html_safe
  out << '</SCRIPT>'.html_safe
  return out
end

def date_select_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
