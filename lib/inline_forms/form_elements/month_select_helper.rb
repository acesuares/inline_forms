# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MonthSelectHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # date
    def month_select_show(object, attribute)
      link_to_inline_edit object, attribute, (1..12).include?(object[attribute]) ?  I18n.localize(Date.new(1970,object[attribute],1), :format => '%B') : "<i class='fi-plus'></i>".html_safe, from_callee: __callee__
    end
    
    def month_select_edit(object, attribute)
      select_month( (1..12).include?(object[attribute]) ?  Date.new(1970, object[attribute], 1) : Date.today, field_name: attribute )
      # ( object.send(attribute).nil? ? "" : object.send(attribute).strftime("%d-%m-%Y") ), :id => css_id, :class =>'datepicker'
    end
    
    def month_select_update(object, attribute)
      object[attribute.to_sym] = params['date'][attribute] rescue 0
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
