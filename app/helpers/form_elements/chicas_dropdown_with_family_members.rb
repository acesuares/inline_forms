# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to

# dropdown
def chicas_dropdown_with_family_members_show(object, attribute)
  attribute_value = object.send(attribute)._dropdown_presentation rescue  "<i class='fi-plus'></i>".html_safe
  link_to_inline_edit object, attribute, attribute_value
end

def chicas_dropdown_with_family_members_edit(object, attribute)
  o = object.send(attribute) # the client
  values = o.family.clients
  values.sort_by(&:_dropdown_presentation)
  # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
  collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', '_dropdown_presentation', :selected => object.send(attribute).id)
end

def chicas_dropdown_with_family_members_update(object, attribute)
  foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.to_s.foreign_key.to_sym
  old_path = File.dirname(object.image.path)
  object[foreign_key] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_s.foreign_key.to_sym]
  if object.save
   # move to new location
   new_path = File.join(Rails.root, "public/uploads/client/photo/#{object.client_id}")
   system "mkdir -vp #{new_path}"
   system "mv -v #{old_path} #{new_path}"
  end
end

