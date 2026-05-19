# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module PlainTextHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def plain_text_show(object, attribute)
      InlineForms.assert_plain_text_column!(object: object, attribute: attribute, form_element: :plain_text)
      value = object[attribute]
      link_to_inline_edit object, attribute, (value.nil? || value.empty?) ? "<i class='fi-plus'></i>".html_safe : value, from_callee: __callee__
    end
    
    def plain_text_edit(object, attribute)
      InlineForms.assert_plain_text_column!(object: object, attribute: attribute, form_element: :plain_text)
      text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
    end
    
    def plain_text_update(object, attribute)
      InlineForms.assert_plain_text_column!(object: object, attribute: attribute, form_element: :plain_text)
      object[attribute.to_sym] = params[attribute.to_sym]
    end
    
    def plain_text_info(object, attribute)
      InlineForms.assert_plain_text_column!(object: object, attribute: attribute, form_element: :plain_text)
      object[attribute]
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
