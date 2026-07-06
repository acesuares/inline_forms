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
    
    # Native <input type="month"> (8.1.25; replaces the jQuery UI month/year
    # datepicker hack). Submits ISO "YYYY-MM"; stored as the first of month.
    def month_year_picker_edit(object, attribute)
      css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
      month_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).strftime("%Y-%m") ), :id => css_id, :class => 'month_year_picker'
    end
    
    def month_year_picker_update(object, attribute)
      raw = params[attribute.to_sym].to_s
      object[attribute.to_sym] =
        if raw.empty?
          nil
        elsif raw.match?(/\A\d{4}-\d{2}\z/)
          # <input type="month"> value; Date.parse would raise on it.
          Date.strptime(raw, "%Y-%m").strftime("%F")
        else
          # Legacy "September 2026" style (pre-8.1.25 clients / tests).
          Date.parse(raw).strftime("%F")
        end
    rescue Date::Error
      object[attribute.to_sym] = nil
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
