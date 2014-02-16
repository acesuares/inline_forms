# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def info_list_show(object, attribute)
  # we would expect 
  out = ''
  out = "<div class='row #{cycle('odd', 'even')}'>--</div>" if object.send(attribute).empty? 
  object.send(attribute).sort.each do | item |
    out << "<div class='row #{cycle('odd', 'even')}'>"
    out << item._presentation
    out << '</div>'
  end
  out.html_safe
end

def info_list_edit(object, attribute)
  # we should raise an error
end

def info_list_update(object, attribute)
  # we should raise an errror
end
