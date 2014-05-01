# -*- encoding : utf-8 -*-
#InlineForms::SPECIAL_COLUMN_TYPES[:text_field]=:string

def move_show(object, attribute)
  link_to_inline_edit object, attribute, "<i class='fi-plus'></i>".html_safe
end

def move_edit(object, attribute)
  values = object.class.send :hash_tree_to_collection
    select( ('_' + object.class.to_s.underscore).to_sym, attribute, values, :selected => object.id )
end

def move_update(object, attribute)
  # parent = object.class.find_by_id(params['_' + object.class.to_s.underscore][attribute.to_sym])
  # parent.add_child(object) if parent
  sibling = object.class.find_by_id(params['_' + object.class.to_s.underscore][attribute.to_sym])
  sibling.append_sibling(object)
end

