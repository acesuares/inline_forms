module InlineFormsHelper
  # checklist
  def checklist_show(object, attribute, values)
    out = '<ul class="checklist">'
    out << link_to_inline_edit(object, attribute, nil, nil) if object.send(attribute).empty?
    object.send(attribute).sort.each do | item |
      out << '<li>'
      out << link_to_inline_edit(object, attribute, item.title, nil)
      out << '</li>'
    end
    out <<  '</ul>'
  end
  def checklist_edit(object, attribute, values)
    object.send(attribute).build  if object.send(attribute).empty?
    values = object.send(attribute).first.class.name.constantize.find(:all) # TODO bring order
    out = '<div class="edit_form_checklist">'
    out << '<ul>'
    values.each do | item |
      out << '<li>'
      out << check_box_tag( attribute + '[' + item.id.to_s + ']', 'yes', object.send(attribute.singularize + "_ids").include?(item.id) )
      out << '<div class="edit_form_checklist_text">'
      out << h(item.title)
      out << '</div>'
      out << '<div style="clear: both;"></div>'
      out << '</li>'
    end
    out << '</ul>'
    out << '</div>'
  end
  def checklist_update(object, attribute, values)
    params[attribute] ||= {}
    object.send(attribute.singularize + '_ids=', params[attribute].keys)
  end
end

