# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:month_year_picker]=:date

# date
def month_year_picker_show(object, attribute)
  link_to_inline_edit object, attribute, object.send(attribute).nil? ? "<i class='fi-plus'></i>".html_safe : object.send(attribute).strftime("%B %Y"), from_callee: __callee__
end

def month_year_picker_edit(object, attribute)
  css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
  out = text_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).strftime("%B %Y") ), :id => css_id, :class =>'datepicker datepicker-month-year'
end

def month_year_picker_update(object, attribute)
  puts 'XXXXXXXXXXXXXXXXXXXXXXXXXX' + object[attribute.to_sym].inspect
  puts 'XXXXXXXXXXXXXXXXXXXXXXXXXX' + Date.parse(params[attribute.to_sym].to_s).strftime("%F").to_s
  object[attribute.to_sym] = Date.parse(params[attribute.to_sym].to_s).strftime("%F").to_s
  puts 'XXXXXXXXXXXXXXXXXXXXXXXXXX' + object[attribute.to_sym].inspect
end
