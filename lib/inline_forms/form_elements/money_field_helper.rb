# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MoneyFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def money_field_show(object, attribute)
      # Two money-rails-specific quirks the bare helper used to leak:
      #   1. `humanized_money_with_symbol(nil)` returns "", which renders
      #      as an empty `<a>` tag. Fall back to the empty-state
      #      placeholder used by the other choice helpers instead.
      #   2. `humanized_money_with_symbol` defaults `no_cents_if_whole: true`,
      #      so whole-dollar amounts show without cents ("$124" instead of
      #      "$124.00"). That's inconsistent with non-whole amounts ("$12.34")
      #      and looks like a precision bug on values that rounded up to a
      #      whole dollar (e.g. `Money.from_amount(123.999, "USD")` rounds
      #      to 12400 cents → "$124" by default; "$124.00" with the override).
      #      Always show cents.
      value = object.send(attribute)
      label = if value.blank?
                "<i class='fi-plus'></i>".html_safe
              else
                humanized_money_with_symbol(value, no_cents_if_whole: false)
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
