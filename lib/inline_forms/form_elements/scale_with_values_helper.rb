# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module ScaleWithValuesHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # scale_with_values generates a scale
    # with the given list of values as options
    #
    # values must be a hash { integer => string, ... } or an one-dimensional array of strings
    def scale_with_values_show(object, attribute)
      # `attribute_values` returns [[key, label], ...] pairs. With a hash
      # input the keys are the user-defined integers; with an array input
      # they are the positional 0..N-1. Either way Array#assoc looks up
      # by the stored value rather than treating it as a positional index.
      values = attribute_values(object, attribute)
      pair = values.assoc(object.send(attribute))
      label = pair ? pair[1] : "<i class='fi-plus'></i>".html_safe
      link_to_inline_edit object, attribute, label, from_callee: __callee__
    end
    
    def scale_with_values_edit(object, attribute)
      # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
      values = attribute_values(object, attribute)
      collection_select( ('_' + object.class.to_s.underscore).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
    end
    
    def scale_with_values_update(object, attribute)
      object[attribute.to_sym] = params[('_' + object.class.to_s.underscore).to_sym][attribute.to_sym]
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
