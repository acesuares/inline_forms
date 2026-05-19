# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module HeaderHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def header_show(object, attribute)
      # show the header which is the translated fake attribute
      attribute
    end
    
    def header_edit(object, attribute)
      # just show the header
      attribute
    end
    
    def header_update(object, attribute)
      # do absolutely nothing
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
