# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module SliderWithValuesHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # slider_with_values -- native <input type="range"> since 8.1.26 (replaces
    # the jQuery UI slider and its inline <script>). The label text next to the
    # slider is kept in sync by initInlineFormsWidgets (class hook
    # `slider_with_values`, labels in data-slider-values, target <output> id in
    # data-slider-output); helpers emit no per-field scripts.
    def slider_with_values_show(object, attribute)
      values = attribute_values(object, attribute)
      value = object.send(attribute).to_i         # should be an int
      # values should be [ [ 0, value ], [ 3, value2 ] .... ] and we lookup the
      # key, not the place in the array! A value with no entry (e.g. 0 when the
      # values hash starts at 1) falls back to the bare number instead of
      # crashing (pre-8.1.26 code did values.assoc(value)[1] unguarded).
      display_value = (pair = values.assoc(value)) ? pair[1] : value.to_s
      css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
      if value == 0
        out = "?"   # we use this as the 'unknown' value. So in the data, 0 should always be the unknown value. This gives problems with sliders where the real value is 0.
      else
        # <progress> (not a disabled <input type=range>): the show panel is
        # wrapped in the inline-edit link, and a disabled input would swallow
        # the click; progress is non-interactive so the click-to-edit works.
        out = "".html_safe
        out << content_tag(:progress, nil,
                           value: value,
                           max: values.collect(&:first).max.to_i,
                           class: "slider slider_#{attribute}",
                           id: "slider_#{css_id}")
        out << content_tag(:div, display_value, class: 'slider_value', id: "value_#{css_id}")
        out << "<div style='clear: both'></div>".html_safe
      end
      link_to_inline_edit object, attribute, out, from_callee: __callee__
    end
    
    def slider_with_values_edit(object, attribute)
      # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
      values = attribute_values(object, attribute)
      value = object.send(attribute).to_i         # should be an int, will be 0 if nil
      css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
      display_value = (pair = values.assoc(value)) ? pair[1] : value.to_s
      labels = values.collect { |x| x[1] }
      out = "".html_safe
      out << range_field_tag("_#{object.class.to_s.underscore}[#{attribute}]", value,
                             id: "input_#{css_id}",
                             class: "slider slider_#{attribute} slider_with_values",
                             in: 0..(values.collect(&:first).max.to_i),
                             step: 1,
                             data: { slider_values: labels.to_json,
                                     slider_output: "value_#{css_id}" })
      out << content_tag(:output, display_value, class: 'slider_value', id: "value_#{css_id}")
      out << "<div style='clear: both'></div>".html_safe
      out
    end
    
    def slider_with_values_update(object, attribute)
      object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
