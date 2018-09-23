# -*- encoding : utf-8 -*-
#InlineForms::SPECIAL_COLUMN_TYPES[:absence_list]=:no_migration

# checklist
def absence_list_show(object, attribute) # the object is the lesson, attribute should be absences???
  absence_status = { 1 => 'aanwezig', 3 => 'laat met reden', 4 => 'laat' , 5 => 'afwezig met reden', 6 => 'afwezig' }
  out = '<ul class="absence_list">'
  out << link_to_inline_edit(object, attribute) if object.send(attribute).empty? # no absences yet
  object.kids.sort.each do | item | # we need the kids from this lesson.

  out << "<li>"
    out << "#{item.full_name}: "
    out << "<br />"
    out << "<span id='absence_#{Absence.this_lesson_this_kid(object, item).id}_status'>"
    out << link_to_inline_edit( Absence.this_lesson_this_kid(object, item),
                                :status,
                                absence_status[Absence.this_lesson_this_kid(object, item).status],
                                :dropdown_with_values
                              )
    out << '</span>'
    out << '</li>'
  end
  out <<  '</ul>'
  out.html_safe
end

def absence_list_edit(object, attribute)
  # object.send(attribute).build  if object.send(attribute).empty?
  # values = object.send(attribute).first.class.name.constantize.find(:all) # TODO bring order
  out = '<div class="edit_form_checklist">'
  out << '<ul>'
  item = object.kid
    out << "<li>"
    out << item._presentation
    out << dropdown_with_values_edit(Absence.this_lesson(item).first, :status)
    out << '</li>'
  out << '</ul>'
  out << '</div>'
  out.html_safe
end

# def absence_list_update(object, attribute)
#   params[attribute] ||= {}
#   object.send(attribute.singularize + '_ids=', params[attribute].keys)
# end
