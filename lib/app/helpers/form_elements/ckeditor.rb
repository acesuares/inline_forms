# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:ckeditor]=:text

def ckeditor_show(object, attribute)
  # "</div><script>$('#".html_safe +
  # "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}" + "').ckeditor();</script>".html_safe

    link_to_inline_edit object,
      attribute,
      '<div class="ckeditor_area">'.html_safe +
      text_area_tag(  attribute,
                      object[attribute],
                      :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
                    ) +
      image_tag(  'glass_plate.gif',
                  :class => "glass_plate",
                  :title => '' ) +
      "</div><script>$('#".html_safe +
      "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}" + "').ckeditor();</script>".html_safe
end

def ckeditor_edit(object, attribute)
    text_area_tag( attribute,
                    object[attribute],
                    :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
                  ) +
                  "<script>$('#".html_safe +
                  "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}" + "').ckeditor();</script>".html_safe
end

def ckeditor_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
