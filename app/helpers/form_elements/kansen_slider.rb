# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:kansen_slider]=:integer

# kansen_slider
def kansen_slider_show(object, attribute)
  values = attribute_values(object, attribute)
  value = object.send(attribute).to_i         # should be an int
  display_value = values.assoc(value)[1]      # values should be [ [ 0, value ], [ 3, value2 ] .... ] and we lookup the key, not the place in the array!
  css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
  if value == 0 || value > 5 
    out = display_value
  else
    out = "<div class='row collapse'>".html_safe
    out << "<div class='small-5 column slider_value' id='value_#{css_id}'>#{display_value}</div>".html_safe
    out << "<div class='small-7 column kansen_slider_show slider slider_#{attribute.to_s}' id='slider_#{css_id}'></div>".html_safe
    out << "<input type='hidden' name='_#{object.class.to_s.underscore}[#{attribute}]' value='0' id='input_#{css_id}' />".html_safe
    out << ('<script>
              $(function() {
                var displayvalues = ' + values.collect {|x| x[1]}.inspect + ';
                $( "#slider_' + css_id + '" ).slider(
                  {
                    value:' + value.to_s + ',
                    disabled: true,
                    min: 1,
                    max: 5,
                    step: 1,
                  }
                );
              });
             </script>').html_safe
    out << "</div>".html_safe
  end
  link_to_inline_edit object, attribute, out
end

def kansen_slider_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  value = object.send(attribute).to_i         # should be an int, will be 0 if nil
  css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
  display_value = values.assoc(value)[1]      # values should be [ [ 0, value ], [ 3, value2 ] .... ] and we lookup the key, not the place in the array!
  out = "<div class='row collapse'>".html_safe
  out << "<div class='small-5 column kansen_slider_value' id='value_#{css_id}'>#{display_value}</div>".html_safe
  out << "<div class='small-7 column kansen_slider_edit slider slider_#{attribute.to_s}' id='slider_#{css_id}'></div>".html_safe
  out << "<input type='hidden' name='_#{object.class.to_s.underscore}[#{attribute}]' value='0' id='input_#{css_id}' />".html_safe
  out << ('<script>
	$(function() {
    var displayvalues = ' + values.collect {|x| x[1]}.inspect + ';
		$( "#slider_' + css_id + '" ).slider(
      {
        value:' + value.to_s + ',
        min: 0,
        max: ' + (values.length - 1 ).to_s + ',
        step: 1,
        slide: function( event, ui ) {
          $( "#input_' + css_id + '" ).val( ui.value );
          $( "#value_' + css_id + '" ).html( displayvalues[ui.value] );
        }
  		}
    );').html_safe
  out << ('$( "#value_' + css_id + '" ).html(displayvalues[' + value.to_s + ']);').html_safe
	out << ('$( "#input_' + css_id + '" ).val(' + value.to_s + ');').html_safe
	out << ('});
	</script>').html_safe
	out << '</div>'.html_safe
  out
end

def kansen_slider_update(object, attribute)
  object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
end

#<style>
#	#demo-frame > div.demo { padding: 10px !important; };
#	</style>
#
#
#
#<div class="demo">
#
#<p>
#	<label for="amount">Donation amount ($50 increments):</label>
#	<input type="text" id="amount" style="border:0; color:#f6931f; font-weight:bold;" />
#</p>
#
#<div id="slider"></div>
#
#</div><!-- End demo -->
#
