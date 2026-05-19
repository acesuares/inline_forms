# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module InfoListHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
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
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
