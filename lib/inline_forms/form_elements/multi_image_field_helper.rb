# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module MultiImageFieldHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # A `mount_uploaders` (plural) column returns an *array* of uploaders; the
    # pre-8.1.28 code called `.url` on that array and raised NoMethodError the
    # moment a multi_image_field actually held images. Render every image
    # (using the `palm` thumb version when the uploader defines one), and keep
    # accepting a bare single uploader for backward compatibility.
    def multi_image_field_show(object, attribute)
      o = object.send(attribute)
      msg = "<i class='fi-plus'></i>".html_safe
      if o.send(:present?)
        uploads = o.is_a?(Array) ? o : [o]
        rendered = uploads.filter_map do |u|
          next unless u.respond_to?(:url) && u.url.present?
          u.respond_to?(:palm) ? image_tag(u.palm.url) : image_tag(u.url)
        end
        msg = safe_join(rendered) unless rendered.empty?
      end
      link_to_inline_edit object, attribute, msg, from_callee: __callee__
    end
    
    # `name="gallery[]"`: file_field_tag with `multiple:` does not add the []
    # itself, and without it Rack keeps only the last file — the update then
    # stored a single image. With [] the params value is an array, which is
    # what a mount_uploaders (plural) setter expects.
    def multi_image_field_edit(object, attribute)
      file_field_tag "#{attribute}[]", multiple: true, class: 'input_text_field multi_image_field'
    end
    
    def multi_image_field_update(object, attribute)
      files = params[attribute.to_sym]
      return if files.blank?
      object.send(attribute.to_s + '=', Array(files))
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
