# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MoneyFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def money_field_show(object, attribute)
      # `humanized_money_with_symbol` (money-rails) returns "" for nil/blank
      # which renders as an empty anchor — show the empty-state placeholder
      # instead, matching the nil branch on dropdown/radio show helpers.
      value = object.send(attribute)
      label = if defined?(humanized_money_with_symbol) && value.respond_to?(:zero?) && !value.zero?
                humanized_money_with_symbol(value)
              elsif value.blank?
                "<i class='fi-plus'></i>".html_safe
              else
                humanized_money_with_symbol(value)
              end
      link_to_inline_edit object, attribute, label, from_callee: __callee__
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
