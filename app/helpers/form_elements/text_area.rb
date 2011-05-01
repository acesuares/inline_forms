InlineForms::SPECIAL_COLUMN_TYPES[:text_area]=:text

def text_area_show(object, attribute)
  link_to_inline_edit object,
                      attribute,
                      ckeditor_textarea(  object.class,
                                          attribute,
                                          :width => '100%',
                                          :height => '200px',
                                          :value => object[attribute],
                                          :toolbar => "None",
                                          :resize_enabled => "false",
                                          :toolbarCanCollapse => false ) +
                      raw('<img class="window_pane" src="/images/clear.gif" />')
end

def text_area_edit(object, attribute)
#  text_area_tag attribute, object[attribute], :class => 'attribute_text_area'
  ckeditor_textarea(object.class, attribute, :width => '100%', :height => '200px', :value => object[attribute], :name => attribute )
end

def text_area_update(object, attribute)
  object[attribute.to_sym] = params[attribute.to_sym]
end
