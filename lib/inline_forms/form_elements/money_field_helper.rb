# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MoneyFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def money_field_show(object, attribute)
      link_to_inline_edit object, attribute, humanized_money_with_symbol(object.send attribute), from_callee: __callee__
    end
    
    def money_field_edit(object, attribute)
      text_field_tag attribute, (object.send attribute), :class => 'input_money_field'
    end
    
    def money_field_update(object, attribute)
      object.send( "#{attribute}=", params[attribute])
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
