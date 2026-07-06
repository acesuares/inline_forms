# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DropdownWithOtherHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # dropdown
    def dropdown_with_other_show(object, attribute)
      attribute = attribute.to_s
      foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.foreign_key.to_sym
      id = object[foreign_key]
      if id == 0
        attribute_value = object[attribute + '_other']
        attribute_value = "<i class='fi-plus'></i>".html_safe if attribute_value.nil? || attribute_value.empty?
      else
        attribute_value = object.send(attribute)._presentation rescue  "<i class='fi-plus'></i>".html_safe
      end
      link_to_inline_edit object, attribute, attribute_value, from_callee: __callee__
    end
    
    # Native combobox (8.1.26; replaces the jQuery UI autocomplete widget and
    # its inline <script>): a text input backed by a <datalist> of the existing
    # records. Typing a listed presentation picks that record; any other text
    # becomes the free-form "other" value. The old hidden <select> is gone --
    # dropdown_with_other_update never read the posted foreign key anyway (it
    # re-derives it by name lookup from the submitted text).
    def dropdown_with_other_edit(object, attribute)
      attribute = attribute.to_s
      foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.foreign_key.to_sym
      o = attribute.camelcase.constantize
      values = o.all
      values = o.accessible_by(current_ability) if cancan_enabled?
    
      current =
        if object[foreign_key].to_i == 0
          object[attribute + '_other'].to_s
        else
          (object.send(attribute)._presentation rescue '')
        end
    
      input_name  = '_' + object.class.to_s.underscore + '[' + attribute + '_other]'
      input_id    = '_' + object.class.to_s.underscore + '_' + object.id.to_s + '_' + foreign_key.to_s
      datalist_id = input_id + '_options'
    
      options = values.map { |v| content_tag(:option, nil, value: v._presentation) }.join.html_safe
    
      text_field_tag(input_name, current,
                     id: input_id,
                     list: datalist_id,
                     class: 'dropdown_with_other',
                     autocomplete: 'off') +
        content_tag(:datalist, options, id: datalist_id)
    end
    
    def dropdown_with_other_update(object, attribute)
      attribute = attribute.to_s
      foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.foreign_key.to_sym
      # if there is an attribute attr, then there must be an attribute attr_other
      other = params[('_' + object.class.to_s.underscore).to_sym][(attribute + "_other").to_sym]
      # see if it matches anything (but we need to look at I18n too!
      lookup_model = attribute.camelcase.constantize
      name_field = 'name_' + I18n.locale.to_s
      name_field = 'name' unless lookup_model.new.respond_to? name_field
      match = lookup_model.where(name_field.to_sym => other).first # problem if there are dupes!
      match.nil? ? object[foreign_key] = 0 : object[foreign_key] = match.id # problem if there is a record with id: 0 !
      match.nil? ? object[attribute + '_other'] = other : object[attribute + '_other'] = nil  
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
