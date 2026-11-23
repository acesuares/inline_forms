# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module DropdownHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # dropdown
    def dropdown_show(object, attribute)
      attr = object.send attribute
      presentation = "_presentation"
      presentation = "_dropdown_presentation" if attr.respond_to? "_dropdown_presentation"
      attribute_value = object.send(attribute).send(presentation) rescue  "<i class='fi-plus'></i>".html_safe
      link_to_inline_edit object, attribute, attribute_value, from_callee: __callee__
    end
    
    def dropdown_edit(object, attribute)
      object.send('build_' + attribute.to_s) unless object.send(attribute) # we really need this!
      attr = object.send attribute
      presentation = "_presentation"
      presentation = "_dropdown_presentation" if attr.respond_to? "_dropdown_presentation"
      klass = object.send(attribute).class
      values = InlineForms::DropdownOrder.apply(dropdown_offered(klass))
      options_disabled = nil
      if klass.method_defined? :disabled_for_dropdown?
        # loads values; collection_select below reuses the loaded records
        options_disabled = values.map{|v| v.id if v.disabled_for_dropdown?}.compact
      end
      # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
      collection_select( ('_' + object.class.to_s.underscore).to_sym,
                          attribute.to_s.foreign_key.to_sym,
                          values,
                          'id',
                          presentation,
                          selected: (object.send(attribute).id rescue nil),
                          disabled: options_disabled,
                        )
    end
    
    # The records the dropdown offers; dropdown_update accepts no others.
    def dropdown_offered(klass)
      cancan_enabled? ? klass.accessible_by(current_ability) : klass.all
    end
    
    def dropdown_update(object, attribute)
      # Inline edit posts the value under the leading-underscore wrapper key
      # (`params[:_apartment][:owner_id]`); top-level create through a
      # bypassing form (e.g. integration tests posting `{name:, title:}`
      # directly) may not include that wrapper at all. Treat a missing
      # wrapper as "do not touch the foreign key" so unrelated attribute
      # walks do not raise NoMethodError on nil[:owner_id].
      scope = params[('_' + object.class.to_s.underscore).to_sym]
      return if scope.blank?
      reflection = object.class.reflect_on_association(attribute.to_sym)
      foreign_key = reflection.options[:foreign_key] || attribute.to_s.foreign_key.to_sym
      value = scope[attribute.to_s.foreign_key.to_sym]
      # A hidden option is also a refused value. The value the record already
      # has may stay. It is assigned all the same, so that a model that refuses
      # it says so in its own words; RefusedValues keeps it from being saved.
      if value.present? && value.to_s != object[foreign_key].to_s &&
          !dropdown_offered(reflection.klass).exists?(reflection.klass.primary_key => value.to_s)
        InlineForms::RefusedValues.add(object, attribute)
      end
      object[foreign_key] = value
    end
    
    def dropdown_info(object, attribute)
      attr = object.send attribute
      presentation = "_presentation"
      presentation = "_dropdown_presentation" if attr.respond_to? "_dropdown_presentation"
      object.send(attribute).send(presentation) rescue  "-"
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
