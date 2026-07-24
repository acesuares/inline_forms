# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module SimpleFileFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def simple_file_field_show(object, attribute)
      o = object.send(attribute)
      attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list
      values = attributes.assoc(attribute.to_sym)[2]
      raise "inline_forms: no values defined in #{object.class} for #{attribute} (add a values hash to the inline_forms_attribute_list row)" if values.nil?
      method = values.is_a?(Hash) ? values.sort_by { |k, _| k }.first[1] : values.first
      if o.send(:present?)
        filename = o.to_s
        model = object.class.to_s.pluralize.underscore
        link_to filename, "/#{model}/#{method}/#{object.id}", data: { turbo: false } # route must exist!! turbo:false so the browser downloads send_data natively instead of Turbo loading it into the frame
      else
        link_to_inline_edit object, attribute, "<i class='fi-plus'></i>".html_safe, from_callee: __callee__
      end
    end
    
    def simple_file_field_edit(object, attribute)
      file_field_tag attribute, :class => 'input_text_field'
    end
    
    def simple_file_field_update(object, attribute)
      object.send(attribute.to_s + '=', params[attribute.to_sym])
    end
    
    # You need to add a route to your routes.rb file: 
    # get '/:model/dl/:id' => 'your_controller#download', :as => 'download'
    # and a method to your controller:
    # def download
    # FIXME
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
