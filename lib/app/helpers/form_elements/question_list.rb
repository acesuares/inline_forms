#InlineForms::SPECIAL_COLUMN_TYPES[:question_list]=:no_migration

# checklist
def question_list_show(object, attribute)
  out = '<ul class="question_list">'
  out << link_to_inline_edit(object, attribute) if object.send(attribute).empty?
  object.send(attribute).sort.each do | item |
    out << '<li>'
    out << link_to_inline_edit(object, attribute, item._presentation )
    out << '</li>'
  end
  out <<  '</ul>'
  out.html_safe
end

def question_list_edit(object, attribute)
  object.send(attribute).build  if object.send(attribute).empty?
  values = object.send(attribute).first.class.name.constantize.find(:all) # TODO bring order
  out = '<div class="edit_form_checklist">'
  out << '<ul>'
  Question.all.each do | question |
    out << '<li>'
    out << h(question._presentation)
    unless question.subquestions.empty?
      out << '<ul>'
      question.subquestions.each do | subquestion |
        out << '<li>'
        out << h(subquestion._presentation)
        out << '</li>'
      end
      out << '</ul>'
    end
    out << '</li>'
  end
  out << '</ul>'
  out << '</div>'
  out.html_safe
end

def question_list_update(object, attribute)
  params[attribute] ||= {}
  object.send(attribute.singularize + '_ids=', params[attribute].keys)
end
