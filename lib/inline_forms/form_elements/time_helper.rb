# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module TimeHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
      # time
      def time_select_show(object, attribute)
        link_to_inline_edit object, attribute, object.send(attribute).nil? ? "<i class='fi-plus'></i>".html_safe : object.send(attribute).to_datetime.strftime("%l:%M%P"), from_callee: __callee__
      end
    
      # Native <input type="time"> (8.1.25; replaces the jQuery timepicker).
      # Submits 24h "HH:MM", which Active Record casts directly to a time column.
      def time_select_edit(object, attribute)
        css_id = 'timepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
        time_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).to_datetime.strftime("%H:%M") ), :id => css_id, :class => 'time_select'
      end
    
      def time_select_update(object, attribute)
        object[attribute.to_sym] = params[attribute.to_sym]
      end
    
      def time_select_info(object, attribute)
        object.send(attribute).nil? ? "-" : object.send(attribute).to_date
      end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
