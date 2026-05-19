# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module CkeditorHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    # Legacy type name: CKEditor is removed; behaves like :rich_text.
    
    def ckeditor_show(object, attribute)
      rich_text_show(object, attribute)
    end
    
    def ckeditor_edit(object, attribute)
      rich_text_edit(object, attribute)
    end
    
    def ckeditor_update(object, attribute)
      rich_text_update(object, attribute)
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
