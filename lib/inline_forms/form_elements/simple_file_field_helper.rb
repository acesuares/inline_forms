# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module SimpleFileFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # Two modes. A declared file slot (InlineForms::StoredFiles + routes from
    # InlineForms.file_routes) renders the slot partial: download through the
    # gem, replace / remove / undo icons by permission. Anything else keeps the
    # legacy behaviour below: a link to the host's download route named in the
    # values hash, and an edit link only while the field is empty.
    def simple_file_field_show(object, attribute)
      if inline_forms_file_slot_active?(object, attribute)
        return render(partial: "inline_forms/file_slot", locals: { object: object, attribute: attribute })
      end
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
      field = file_field_tag attribute, :class => 'input_text_field'
      return field unless object.class.respond_to?(:inline_forms_file_slot?) && object.class.inline_forms_file_slot?(attribute)

      field = file_field_tag attribute, class: 'input_text_field', required: true
      return field unless object.inline_forms_file_present?(attribute)

      # Replacing: say which file goes, and where it goes.
      hint = t("inline_forms.files.replace_hint", filename: object[attribute.to_s])
      safe_join([ field, content_tag(:span, hint, class: "inline_forms-file-hint") ])
    end
    
    def simple_file_field_update(object, attribute)
      value = params[attribute.to_sym]
      if object.class.respond_to?(:inline_forms_file_slot?) && object.class.inline_forms_file_slot?(attribute)
        # A declared slot only takes an uploaded file from a request (a crafted
        # string would set a filename without bytes). Nothing chosen is a
        # validation error, not a silent success.
        if value.respond_to?(:original_filename)
          object.send(attribute.to_s + '=', value)
        else
          object.inline_forms_file_missing!(attribute)
        end
        return
      end
      object.send(attribute.to_s + '=', value)
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
