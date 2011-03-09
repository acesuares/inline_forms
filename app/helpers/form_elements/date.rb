module InlineFormsHelper
    InlineForms::SPECIAL_COLUMN_TYPES[:date_select]=:date

  # date
  def date_select_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def date_select_edit(object, attribute, values)
    out = text_field_tag attribute, object[attribute]
    out << '<SCRIPT>'.html_safe
    out << "$(function() { ".html_safe
    out << '$("#'.html_safe + attribute.to_s.html_safe + '").datepicker();'.html_safe
    out << '});'.html_safe
    out << '</SCRIPT>'.html_safe
    return out
  end
  def date_select_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end
end
