# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:geo_code_curacao]=:string

# geo_code_curacao
def geo_code_curacao_show(object, attribute)
  attribute_value = GeoCodeCuracao.new(object.send(attribute)).presentation rescue nil
  link_to_inline_edit object, attribute, attribute_value
end
def geo_code_curacao_edit(object, attribute)
  attribute_value = object.send(attribute).presentation rescue nil
  out = text_field_tag attribute, attribute_value
  out << '<script>
		$( "#geo_code_curacao" ).autocomplete({
			source: "/geo_code_curacao",
			minLength: 2,
			});
	</script>'.html_safe
end

def geo_code_curacao_update(object, attribute)
  # extract the geocode
  geo_code = params[attribute].scan(/\d\d\d\d\d\d/).first || nil
  object[attribute.to_sym] = GeoCodeCuracao.new(geo_code).valid? ? geo_code : nil
end

