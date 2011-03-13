InlineForms::SPECIAL_COLUMN_TYPES[:geo_code_curacao]=:string

# geo_code_curacao
def geo_code_curacao_show(object, attribute)
  attribute_value = object.send(attribute)._presentation rescue nil
  link_to_inline_edit object, attribute, attribute_value
end
def geo_code_curacao_edit(object, attribute)
  text_field_with_auto_complete :geo_code_curacao, :street, :skip_style => true
end
def geo_code_curacao_update(object, attribute)
  # extract the geocode
  geo_code = params[attribute.to_sym][:street].scan(/\d\d\d\d\d\d/).to_s || nil
  object[attribute.to_sym] = GeoCodeCuracao.new(geo_code).valid? ? geo_code : nil
end

