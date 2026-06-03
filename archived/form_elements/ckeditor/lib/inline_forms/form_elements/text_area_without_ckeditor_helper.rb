# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module TextAreaWithoutCkeditorHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    # Legacy alias for plain :text_area (CKEditor removed).
    
    def text_area_without_ckeditor_show(object, attribute)
      plain_text_show(object, attribute)
    end
    
    def text_area_without_ckeditor_edit(object, attribute)
      plain_text_edit(object, attribute)
    end
    
    def text_area_without_ckeditor_update(object, attribute)
      plain_text_update(object, attribute)
    end
    
    def text_area_without_ckeditor_info(object, attribute)
      plain_text_info(object, attribute)
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
