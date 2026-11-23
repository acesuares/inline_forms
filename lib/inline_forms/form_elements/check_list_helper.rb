# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module CheckListHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    # checklist
    def check_list_show(object, attribute)
      out = ''
      out = link_to_inline_edit(object, attribute, "<i class='fi-plus'></i>".html_safe, from_callee: __callee__) if object.send(attribute).empty?
      object.send(attribute).sort.each do | item |
        out << "<div class='row #{cycle('odd', 'even')}'>"
        out << link_to_inline_edit(object, attribute, item._presentation, from_callee: __callee__ )
        out << '</div>'
      end
      out.html_safe
    end
    
    def check_list_edit(object, attribute)
      object.send(attribute).build  if object.send(attribute).empty?
      klass = object.send(attribute).first.class
      values = InlineForms::DropdownOrder.apply(check_list_offered(klass))
      out = ''
      values.each do | item |
        out << "<div class='row #{cycle('odd', 'even')}'>"
        out << check_box_tag( attribute.to_s + '[' + item.id.to_s + ']', 1, object.send(attribute.to_s.singularize + "_ids").include?(item.id) )
        out << "<label for=#{attribute.to_s + '[' + item.id.to_s + ']'}>#{h(item._presentation)}</label>"
        out << '</div>'
      end
      out.html_safe
    end
    
    # The records the check list offers; check_list_update accepts no others.
    def check_list_offered(klass)
      values = cancan_enabled? ? klass.accessible_by(current_ability) : klass.all
      # check_list has always applied the list scope's filter (a where in
      # inline_forms_list hides records here); the order is DropdownOrder's.
      values = values.merge(klass.inline_forms_list.unscope(:order)) if klass.respond_to?(:inline_forms_list)
      values
    end
    
    def check_list_update(object, attribute)
      params[attribute] ||= {}
      ids = attribute.to_s.singularize + '_ids'
      posted = params[attribute].keys.map(&:to_s)
      held = object.send(ids).map(&:to_s)
      offered = check_list_offered(object.class.reflect_on_association(attribute.to_sym).klass).map { |item| item.id.to_s }
      # A hidden record is also a refused one. Nothing is assigned: on a saved
      # record that would write the join rows at once.
      if (posted - offered - held).any?
        InlineForms::RefusedValues.add(object, attribute)
        return
      end
      # Records the user was not shown stay: not ticked is not unticked.
      object.send(ids + '=', posted | (held - offered))
      object.touch unless object.new_record? # Check for new_record needed for Rails > 3; TODO we should have a flag to turn this on or of.
    end
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
