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
    
    def date_select_edit(object, attribute)
      css_id = 'datepicker_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + attribute.to_s
      out = text_field_tag attribute, ( object.send(attribute).nil? ? "" : object.send(attribute).to_date.strftime("%d-%m-%Y") ), :id => css_id, :class =>'datepicker'
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
