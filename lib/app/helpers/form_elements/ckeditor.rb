# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:ckeditor]=:text

def ckeditor_show(object, attribute)
    link_to_inline_edit object,
      attribute,
      '<div class="ckeditor_area">'.html_safe +
      cktext_area_tag(
      attribute,
      object[attribute],
      :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
      :ckeditor => {  :width => '100%',
                      :height => '200px',
                      :toolbar => "None",
                      :readOnly => "true",
                      :resize_enabled => "false",
                      :toolbarCanCollapse => "false"
                    }
    ) +
      image_tag(  'inline_forms/glass_plate.gif',
                  :class => "glass_plate",
                  :title => '' ) +
      "<script>delete CKEDITOR.instances['textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}']</script>".html_safe +
      '</div>'.html_safe
end

def ckeditor_edit(object, attribute)
    cktext_area_tag( attribute,
                    object[attribute],
                    :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
                    :ckeditor => {  :width => '100%',
                                    :height => '200px'
                                  }
                  ) +
    "<script>delete CKEDITOR.instances['textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}']</script>".html_safe
end

def ckeditor_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
