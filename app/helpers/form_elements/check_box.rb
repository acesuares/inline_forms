module InlineFormsHelper
  # boolean, bit unaptly named check_box
  def check_box_show(object, attribute, values)
    values ||= { 'false' => 'no', 'true' => 'yes' }
    link_to_inline_edit object, attribute, values[object.send(attribute).to_s], values
  end
  def check_box_edit(object, attribute, values)
    values ||= { 'false' => 'no', 'true' => 'yes' }
    collection_select( object.class.to_s.downcase, attribute, values, 'first', 'last', :selected => object.send(attribute).to_s)
  end
  def check_box_update(object, attribute, values)
    object[attribute.to_s.to_sym] = params[object.class.to_s.downcase.to_sym][attribute.to_s.to_sym]
  end
end

