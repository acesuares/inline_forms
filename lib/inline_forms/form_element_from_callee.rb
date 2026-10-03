# -*- encoding : utf-8 -*-

module InlineForms
  # Maps +__callee__+ from a +*_show+ helper to the +params[:form_element]+ string
  # (e.g. +:text_field_show+ → +"text_field"+).
  def self.form_element_string_from_callee(from_callee)
    s = from_callee.to_s
    s = s.sub(/\Ablock in /, "")
    s.delete_suffix("_show")
  end

  # Form elements whose +*_show+ helper delegates to another element's, so
  # their edit link carries the delegate's name (+__callee__+ of the inner
  # helper) as +form_element+ instead of the declared one.
  FORM_ELEMENT_DELEGATES = {
    plain_text_area: :plain_text,
    text_area: :rich_text
  }.freeze

  # The +inline_forms_attribute_list+ row for a single-field request, or nil
  # when +attribute+/+form_element+ (both from params) do not name a row the
  # UI could have linked to. The controller uses this as a whitelist before
  # it dispatches +send("#{form_element}_update")+ or touches the attribute.
  def self.attribute_list_row_for(attribute_list, attribute, form_element)
    attribute = attribute.to_s
    form_element = form_element.to_s
    return nil if attribute.empty? || form_element.empty?

    attribute_list.find do |listed_attribute, declared, *|
      next false unless listed_attribute.to_s == attribute

      declared.to_s == form_element ||
        FORM_ELEMENT_DELEGATES[declared.to_s.to_sym].to_s == form_element
    end
  end
end
