# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module PlainTextAreaHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def plain_text_area_show(object, attribute)
      plain_text_show(object, attribute)
    end
    
    def plain_text_area_edit(object, attribute)
      plain_text_edit(object, attribute)
    end
    
    def plain_text_area_update(object, attribute)
      plain_text_update(object, attribute)
    end
    
    def plain_text_area_info(object, attribute)
      plain_text_info(object, attribute)
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
