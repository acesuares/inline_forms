# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:month_select]=:integer

# date
def month_select_show(object, attribute)
  link_to_inline_edit object, attribute, (1..12).include?(object[attribute]) ?  I18n.localize(Date.new(1970,object[attribute],1), :format => '%B') : "<i class='fi-plus'></i>".html_safe
end

def month_select_edit(object, attribute)
  select_month( (1..12).include?(object[attribute]) ?  Date.new(1970, object[attribute], 1) : Date.today, field_name: attribute )
  # ( object.send(attribute).nil? ? "" : object.send(attribute).strftime("%d-%m-%Y") ), :id => css_id, :class =>'datepicker'
end

def month_select_update(object, attribute)
  object[attribute.to_sym] = params['date'][attribute] rescue 0
end
