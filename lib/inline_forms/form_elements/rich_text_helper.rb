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
      # decided on the TEXT of what is shown: a value without any text gets
      # the plus, or the link could be empty and the field could not be
      # opened. That is wider than what the allowlist empties (only an <img>,
      # a <script>, an empty <p>): markup that shows something but holds no
      # text, such as a lone <hr> or a table of empty cells, gets the plus
      # too, and the plus opens the editor with that markup in it.
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
      # hides Trix's attach button there, and inline_forms.js refuses a
      # dropped or pasted file and shows the message in the data attribute.
      classes = 'trix-content attribute_rich_text_area'
      data = {}
      unless rich.respond_to?(:body)
        classes += ' inline_forms-trix-no-files'
        data[:no_files_message] = t('inline_forms.files.not_in_this_field')
      end
      hidden_field_tag(attribute, body, id: input_id) +
        content_tag(:'trix-editor', ''.html_safe, input: input_id, class: classes, data: data)
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
