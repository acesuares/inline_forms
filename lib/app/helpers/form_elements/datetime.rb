InlineForms::SPECIAL_COLUMN_TYPES[:datetime_select]=:date

# datetime
def datetime_select_show(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute)
end

def datetime_select_edit(object, attribute)
  css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
#  out = text_field_tag attribute, object[attribute], :id => css_id
    datepicker_input object.class.to_s.underscore,attribute.to_s
#  out << '<SCRIPT>'.html_safe
#  out << "$(function() { ".html_safe
#  out << '$("#'.html_safe + css_id.html_safe + '").datepicker();'.html_safe
#  out << '});'.html_safe
#  out << '</SCRIPT>'.html_safe
#  return out
end

def datetime_select_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
