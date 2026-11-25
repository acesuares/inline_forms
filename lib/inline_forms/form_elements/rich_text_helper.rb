# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module RichTextHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def rich_text_show(object, attribute)
      rich = object.respond_to?(attribute) ? object.public_send(attribute) : nil
      # A plain column's HTML goes through the display allowlist; Action Text
      # sanitizes its own (InlineForms.rich_text_display_html). Blank is
      # decided on what is shown: a value the allowlist empties (only an
      # <img>, a <script>, an empty <p>) gets the plus, or the link would be
      # empty and the field could not be opened.
      shown = rich.is_a?(String) ? InlineForms.rich_text_display_html(rich) : rich
      is_blank =
        shown.nil? ||
        (shown.respond_to?(:blank?) && shown.blank?) ||
        (shown.respond_to?(:to_plain_text) && shown.to_plain_text.to_s.strip.empty?) ||
        (shown.is_a?(String) && strip_tags(shown).gsub(/[[:space:]]|&nbsp;/, "").empty?)
      display_value =
        if is_blank
          "<i class='fi-plus'></i>".html_safe
        elsif shown.is_a?(String)
          shown
        else
          shown.to_s.html_safe
        end
      link_to_inline_edit object, attribute, display_value, from_callee: __callee__
    end
    
    def rich_text_edit(object, attribute)
      rich = object.respond_to?(attribute) ? object.public_send(attribute) : nil
      body =
        if rich.respond_to?(:body) && !rich.body.nil?
          rich.body.to_s
        elsif rich.respond_to?(:to_s)
          rich.to_s
        else
          ''
        end
      input_id = "trix_input_#{object.class.name.underscore}_#{object.id || 'new'}_#{attribute}"
      # A plain column (no has_rich_text) cannot hold attachments: the class
      # hides Trix's attach button there.
      classes = 'trix-content attribute_rich_text_area'
      classes += ' inline_forms-trix-no-files' unless rich.respond_to?(:body)
      hidden_field_tag(attribute, body, id: input_id) +
        content_tag(:'trix-editor', ''.html_safe, input: input_id, class: classes)
    end
    
    def rich_text_update(object, attribute)
      object.public_send("#{attribute}=", params[attribute.to_sym])
    end
    
    def rich_text_info(object, attribute)
      value = object.respond_to?(attribute) ? object.public_send(attribute) : nil
      value.to_s
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
