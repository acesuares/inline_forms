# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DecimalFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def decimal_field_show(object, attribute)
      # `:decimal_field` columns are real `:decimal(p, s)` since 8.1.10,
      # which means `object[attribute]` returns a `BigDecimal`. Calling
      # `to_s` on a BigDecimal without arguments returns scientific
      # notation (`"0.1234e2"`), not the `"12.34"` users expect — render
      # fixed-point. Strings (legacy varchar columns on apps generated
      # before 8.1.10) and integers/floats also work with `to_s("F")` via
      # their generic `to_s` fallback.
      value = object[attribute]
      label = if value.nil?
                "<i class='fi-plus'></i>".html_safe
              elsif value.is_a?(BigDecimal)
                value.to_s("F")
              else
                value.to_s
              end
      link_to_inline_edit object, attribute, label, from_callee: __callee__
    end

    def decimal_field_edit(object, attribute)
      # Render with fixed-point in the edit textbox for the same reason
      # decimal_field_show does — otherwise the user sees "0.1234e2" in
      # the edit field on an existing value, and round-trips it back.
      value = object.send(attribute.to_sym)
      value = value.to_s("F") if value.is_a?(BigDecimal)
      text_field_tag attribute, value, :class => 'input_decimal_field'  # for abide: , :required => true
    end

    def decimal_field_update(object, attribute)
      object.send :write_attribute, attribute.to_sym, params[attribute.to_sym]
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
