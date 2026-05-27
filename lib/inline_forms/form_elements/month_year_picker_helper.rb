# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MonthYearPickerHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # date
    def month_year_picker_show(object, attribute)
      link_to_inline_edit object, attribute, object.send(attribute).nil? ? "<i class='fi-plus'></i>".html_safe : object.send(attribute).strftime("%B %Y"), from_callee: __callee__
    end
    
    def month_year_picker_edit(object, attribute)
      css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
      out = text_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).strftime("%B %Y") ), :id => css_id, :class =>'datepicker datepicker-month-year'
    end
    
    def month_year_picker_update(object, attribute)
      raw = params[attribute.to_sym].to_s
      object[attribute.to_sym] = raw.empty? ? nil : Date.parse(raw).strftime("%F").to_s
    rescue Date::Error
      object[attribute.to_sym] = nil
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
