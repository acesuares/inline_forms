# -*- encoding : utf-8 -*-
module InlineForms
  # Maps +__callee__+ from a +*_show+ helper to the +params[:form_element]+ string
  # (e.g. +:text_field_show+ → +"text_field"+).
  def self.form_element_string_from_callee(from_callee)
    s = from_callee.to_s
    s = s.sub(/\Ablock in /, "")
    s.delete_suffix("_show")
  end
end
