InlineForms::SPECIAL_COLUMN_TYPES[:slider_with_values]=:integer

# slider_with_values
def slider_with_values_show(object, attribute)
  values = attribute_values(object, attribute)
  value = object.send(attribute)
  display_value = values[value][1]
  css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
  if value == 0
    out = "?"
  else
    out = "".html_safe
    out << "<div class='slider slider_#{attribute.to_s}' id='slider_#{css_id}'></div>".html_safe
    out << "<div class='slider_value' id='value_#{css_id}'>#{display_value}</div>".html_safe
    out << "<div style='clear: both' />".html_safe
    out << "<input type='hidden' name='_#{object.class.to_s.underscore}[#{attribute}]' value='0' id='input_#{css_id}' />".html_safe
    out << ('<script>
              $(function() {
                var displayvalues = ' + values.collect {|x| x[1]}.inspect + ';
                $( "#slider_' + css_id + '" ).slider(
                  {
                    value:' + object.send(attribute).to_s + ',
                    range: "min",
                    disabled: true,
                    min: 0,
                    max: 5,
                    step: 1,
                  }
                );
              });
             </script>').html_safe
  end
  link_to_inline_edit object, attribute, out
end

def slider_with_values_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
  out = "".html_safe
  out << "<div class='slider slider_#{attribute.to_s}' id='slider_#{css_id}'></div>".html_safe
  out << "<div class='slider_value' id='value_#{css_id}'>#{values[object.send(attribute)][1]}</div>".html_safe
  out << "<div style='clear: both' />".html_safe
  out << "<input type='hidden' name='_#{object.class.to_s.underscore}[#{attribute}]' value='0' id='input_#{css_id}' />".html_safe
  out << ('<script>
	$(function() {
    var displayvalues = ' + values.collect {|x| x[1]}.inspect + ';
		$( "#slider_' + css_id + '" ).slider(
      {
        value:' + object.send(attribute).to_s + ',
        range: "min",
        min: 0,
        max: 5,
        step: 1,
        slide: function( event, ui ) {
          $( "#input_' + css_id + '" ).val( ui.value );
          $( "#value_' + css_id + '" ).html( displayvalues[ui.value] );
        }
  		}
    );
		$( "#value_' + css_id + '" ).html(displayvalues[' + object.send(attribute).to_s + ']);
		$( "#input_' + css_id + '" ).val(' + object.send(attribute).to_s + ');
	});
	</script>').html_safe
  out
end
def slider_with_values_update(object, attribute)
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
