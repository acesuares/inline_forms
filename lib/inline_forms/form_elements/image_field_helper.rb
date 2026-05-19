# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module ImageFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def image_field_show(object, attribute)
      o = object.send(attribute)
      msg = "<i class='fi-plus'></i>".html_safe
      if o.send(:present?)
        if o.respond_to? :palm
          msg = image_tag(o.send(:palm).send(:url))
        else
          msg = image_tag(o.send(:url))
        end
      end
      link_to_inline_edit object, attribute, msg, from_callee: __callee__
    end
    
    def image_field_edit(object, attribute)
      file_field_tag attribute, class: 'input_text_field'
    end
    
    def image_field_update(object, attribute)
      object.send(attribute.to_s + '=', params[attribute.to_sym])
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
