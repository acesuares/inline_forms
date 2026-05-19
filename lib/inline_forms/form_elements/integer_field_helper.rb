# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module IntegerFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def integer_field_show(object, attribute)
      link_to_inline_edit object, attribute, object[attribute].nil? ? "<i class='fi-plus'></i>".html_safe : object[attribute], from_callee: __callee__
    end
    
    def integer_field_edit(object, attribute)
      number_field_tag attribute, (object.send attribute.to_sym), :class => 'input_integer_field'  # for abide: , :required => true
    end
    
    def integer_field_update(object, attribute)
      object.send :write_attribute, attribute.to_sym, params[attribute.to_sym]
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
