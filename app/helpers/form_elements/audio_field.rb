# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:audio_field]=:string

def audio_field_show(object, attribute)
  o = object.send(attribute)
  msg = "<i class='fi-pencil' title='Edit #{attribute.to_s}'></i>".html_safe
  if o.send(:present?)
    if o.respond_to? :palm
      audio_html = audio_tag(o.send(:palm).send(:url), autoplay: false, controls: true)
    else
      audio_html = audio_tag(o.send(:url), autoplay: false, controls: true)
    end
  end
  link_to_edit = link_to_inline_edit object, attribute, msg
  if cancan_disabled? || ( can? :update, object, attribute )
    "#{audio_html} #{link_to_edit}".html_safe
  else
    audio_html.html_safe
  end
end

def audio_field_edit(object, attribute)
  file_field_tag attribute, class: 'input_text_field'
end

def audio_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end
