# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DateHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # date
    def date_select_show(object, attribute)
      link_to_inline_edit object, attribute, object.send(attribute).nil? ? "<i class='fi-plus'></i>".html_safe : object.send(attribute).to_date.strftime("%d-%m-%Y"), from_callee: __callee__
    end
    
    # Native <input type="date"> (8.1.25; replaces jQuery UI datepicker).
    # The browser shows a locale-formatted date but always submits ISO 8601
    # (YYYY-MM-DD), which Active Record casts directly.
    def date_select_edit(object, attribute)
      css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
      date_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).to_date.strftime("%F") ), :id => css_id, :class => 'date_select'
    end
    
    def date_select_update(object, attribute)
      object[attribute.to_sym] = params[attribute.to_sym]
    end
    
    def date_select_info(object, attribute)
      object.send(attribute).nil? ? "-" : object.send(attribute).to_date
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
