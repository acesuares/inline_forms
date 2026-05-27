# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DropdownWithValuesHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # dropdown_with_values
    def dropdown_with_values_show(object, attribute)
      # `attribute_values` already runs every label through `t()` (see
      # InlineForms::Helpers#attribute_values). Calling `t()` again here on
      # an already-translated (and possibly already-rendered as
      # `<span class="translation_missing">...</span>`) string used the
      # whole string as an I18n key, so a missing translation rendered the
      # bizarre `<span class="translation_missing" title="Low&quot;&gt;Low&lt;/Span&gt;">…</span>`
      # blob the user spotted on `priority`/`priority2`. Use the already-
      # translated value as-is and fall back to the empty-state placeholder
      # for nil (mirrors radio_button_show and the 8.1.7 scale fixes).
      values = attribute_values(object, attribute)
      pair = object.send(attribute) ? values.assoc(object.send(attribute)) : nil
      label = pair ? pair[1] : "<i class='fi-plus'></i>".html_safe
      link_to_inline_edit object, attribute, label, from_callee: __callee__
    end
    
    def dropdown_with_values_edit(object, attribute)
      # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
      values = attribute_values(object, attribute)
    
      attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list
      options_disabled = attributes.assoc(attribute.to_sym)[3]
    
      collection_select(  ('_' + object.class.to_s.underscore).to_sym,
                          attribute.to_sym,
                          values, 'first', 'last',
                          :selected => object.send(attribute),
                          disabled: options_disabled,
                        )
    end
    
    def dropdown_with_values_update(object, attribute)
      object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
    end
    
    def dropdown_with_values_info(object, attribute)
      # `attribute_values` already translates; do not double-translate here
      # (was the same double-`t()` bug as dropdown_with_values_show).
      values = attribute_values(object, attribute)
      pair = values.assoc(object.send(attribute))
      pair ? pair[1] : '-'
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
