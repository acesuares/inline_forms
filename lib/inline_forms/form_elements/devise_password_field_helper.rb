# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DevisePasswordFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def devise_password_field_show(object, attribute)
      link_to_inline_edit object, attribute, '', from_callee: __callee__
    end
    
    def devise_password_field_edit(object, attribute)
      password_field_tag attribute, '', :class => 'input_devise_password_field'
    end
    
    def devise_password_field_update(object, attribute)
      if params[attribute.to_sym].blank?
        # nothing happens
      else
        object.password = params[attribute.to_sym]
      end
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
