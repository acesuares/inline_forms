# -*- encoding : utf-8 -*-
#InlineForms::SPECIAL_COLUMN_TYPES[:text_field]=:string

def move_show(object, attribute)
  link_to_inline_edit object, attribute, "<i class='fi-plus'></i>".html_safe
end

def move_edit(object, attribute)
  o = object.send(attribute).class.name.constantize
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute, o.all, 'id', 'name', :selected => object.id )
end

def move_update(object, attribute)
  #object.send :write_attribute, attribute.to_sym, params[attribute.to_sym]
end

