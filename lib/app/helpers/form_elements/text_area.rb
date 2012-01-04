InlineForms::SPECIAL_COLUMN_TYPES[:text_area]=:text

def text_area_show(object, attribute)
  if defined? Ckeditor
    link_to_inline_edit object,
      attribute,
      '<div class="ckeditor_area">'.html_safe +
      cktext_area_tag(
      attribute,
      object[attribute],
      :input_html => { :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
        :width => '100%' },
      :height => '200px',
      :toolbar => "None",
      :readOnly => "true",
      :resize_enabled => "false",
      :toolbarCanCollapse => "false"
    ) +
      image_tag(  'glass_plate.gif',
      :class => "glass_plate",
      :title => '' ) +
      '</div>'.html_safe
  else
    link_to_inline_edit object, attribute, object[attribute]
  end
end

def text_area_edit(object, attribute)
  if defined? Ckeditor
    cktext_area_tag(
      attribute,
      object[attribute],
      :input_html => { :id => "textarea_#{object.class.name.underscore}_#{object.id}_#{attribute.to_s}",
        :width => '100%'},
      :height => '200px'
    )
  else
    text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
  end
end

def text_area_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
