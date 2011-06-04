InlineForms::SPECIAL_COLUMN_TYPES[:slider_with_values]=:integer

# slider_with_values
def slider_with_values_show(object, attribute)
  values = attribute_values(object, attribute)
  link_to_inline_edit object, attribute, values[object.send(attribute)][1]
end
def slider_with_values_edit(object, attribute)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  values = attribute_values(object, attribute)
  css_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
  out = "<div id='value_#{css_id}'>#{values[object.send(attribute)][1]}</div>".html_safe
  out << "<div id='slider_#{css_id}'></div>".html_safe
  out << "<input type='hidden' name='_#{object.class.to_s.underscore}[#{attribute}]' value='0' id='input_#{css_id}' />".html_safe
  out << ('<script>
	$(function() {
    var displayvalues = ' + values.collect {|x| x[1]}.inspect + ';
		$( "#slider_' + css_id + '" ).slider({
			value:' + object.send(attribute).to_s + ',
			min: 0,
			max: 5,
			step: 1,
			slide: function( event, ui ) {
				$( "#value_' + css_id + '" ).html( displayvalues[ui.value] );
				$( "#input_' + css_id + '" ).val( ui.value );
			}
		});
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
