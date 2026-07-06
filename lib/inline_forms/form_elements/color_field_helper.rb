# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module ColorFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # color_field (8.1.32): hex color stored as "#rrggbb" in a string column,
    # edited with the native <input type="color"> picker. Introduced for the
    # per-user theme color overrides (Pattern 2), usable anywhere.
    def color_field_show(object, attribute)
      value = object.send(attribute).to_s
      display =
        if value.match?(/\A#\h{6}\z/)
          # Swatch + hex text. The value is validated above, so the inline
          # style cannot carry anything but the color.
          ("<span class='color_swatch' style='display:inline-block;width:1em;height:1em;" \
           "vertical-align:-0.15em;border:1px solid #8888;background-color:#{value};'></span> " \
           "#{value}").html_safe
        else
          "<i class='fi-plus'></i>".html_safe
        end
      link_to_inline_edit object, attribute, display, from_callee: __callee__
    end
    
    def color_field_edit(object, attribute)
      css_id = 'color_field_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
      current = object.send(attribute).to_s
      current = "#000000" unless current.match?(/\A#\h{6}\z/)
      color_field_tag attribute, current, :id => css_id, :class => 'color_field'
    end
    
    def color_field_update(object, attribute)
      raw = params[attribute.to_sym].to_s.strip.downcase
      object[attribute.to_sym] = raw.match?(/\A#\h{6}\z/) ? raw : nil
    end
    
    def color_field_info(object, attribute)
      object.send(attribute).to_s
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
