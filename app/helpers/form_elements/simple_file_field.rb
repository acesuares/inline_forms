# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:simple_file_field]=:string

def simple_file_field_show(object, attribute)
  o = object.send(attribute)
  
  if o.send(:present?)
    filename = o.to_s
    model = object.class.to_s.pluralize.underscore
    link_to filename, "/#{model}/dl/#{object.id}" # route must exist!!
  else
    link_to_inline_edit object, attribute, ''
  end
end

def simple_file_field_edit(object, attribute)
  file_field_tag attribute, :class => 'input_text_field'
end

def simple_file_field_update(object, attribute)
  object.send(attribute.to_s + '=', params[attribute.to_sym])
end

# You need to add a route to your routes.rb file: 
# get '/:model/dl/:id' => 'your_controller#download', :as => 'download'
# and a method to your controller:
# def download
# FIXME