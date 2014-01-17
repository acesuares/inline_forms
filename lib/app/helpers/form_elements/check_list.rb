# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:check_list]=:no_migration

# checklist
def check_list_show(object, attribute)
  out = '<ul class="checklist">'
  out << link_to_inline_edit(object, attribute, "<i class='fi-plus'></i>".html_safe) if object.send(attribute).empty?
  object.send(attribute).sort.each do | item |
    out << '<li>'
    out << link_to_inline_edit(object, attribute, item._presentation )
    out << '</li>'
  end
  out <<  '</ul>'
  out.html_safe
end

def check_list_edit(object, attribute)
  object.send(attribute).build  if object.send(attribute).empty?
  if cancan_enabled?
    values = object.send(attribute).first.class.name.constantize.accessible_by(current_ability).order(attribute.to_s.singularize.camelcase.constantize.order_by_clause)
  else
    values = object.send(attribute).first.class.name.constantize.order(attribute.to_s.singularize.camelcase.constantize.order_by_clause)
  end
  out = ''
  values.each do | item |
    out << "<div class='row #{cycle('odd', 'even')}'>"
    out << check_box_tag( attribute.to_s + '[' + item.id.to_s + ']', 1, object.send(attribute.to_s.singularize + "_ids").include?(item.id) )
    out << "<label for=#{attribute.to_s + '[' + item.id.to_s + ']'}>#{h(item._presentation)}</label>"
    out << '</div>'
  end
  out.html_safe
end

def check_list_update(object, attribute)
  params[attribute] ||= {}
  object.send(attribute.to_s.singularize + '_ids=', params[attribute].keys)
end

