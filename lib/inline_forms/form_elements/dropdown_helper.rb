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
      if cancan_enabled?
        values = klass.accessible_by(current_ability)
      else
        values = klass.all
      end
      options_disabled = nil
      if klass.method_defined? :disabled_for_dropdown?
        options_disabled = values.map{|v| v.id if v.disabled_for_dropdown?}.compact
      end
      values.sort_by {|v|v.send presentation}
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
    
    def dropdown_update(object, attribute)
      # Inline edit posts the value under the leading-underscore wrapper key
      # (`params[:_apartment][:owner_id]`); top-level create through a
      # bypassing form (e.g. integration tests posting `{name:, title:}`
      # directly) may not include that wrapper at all. Treat a missing
      # wrapper as "do not touch the foreign key" so unrelated attribute
      # walks do not raise NoMethodError on nil[:owner_id].
      scope = params[('_' + object.class.to_s.underscore).to_sym]
      return if scope.blank?
      foreign_key = object.class.reflect_on_association(attribute.to_sym).options[:foreign_key] || attribute.to_s.foreign_key.to_sym
      object[foreign_key] = scope[attribute.to_s.foreign_key.to_sym]
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
