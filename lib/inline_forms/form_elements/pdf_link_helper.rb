# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module PdfLinkHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def pdf_link_show(object, attribute)
      # the attribute is the action
      # turbo:false so the links leave the field's turbo-frame: the preview has no matching frame ("Content missing") and the PDF is not HTML; the preview gets its own tab so the record stays open
      # script_name so the links work in an app deployed under a sub-path
      path = "#{request.script_name}/#{attribute}/#{object.id}"
      safe_join([
        link_to(t("inline_forms.files.preview", :default => "preview"), path, :class => "pdf_preview", :target => "_blank", :data => { :turbo => false }),
        link_to(t("inline_forms.files.download_pdf", :default => "download pdf"), "#{path}.pdf", :class => "pdf_open", :data => { :turbo => false })
      ], " | ")
    end
    
    def pdf_link_edit(object, attribute)
      # the attribute is an action: a model needs no method for it
      return unless object.respond_to?(attribute)
      o = object.send(attribute)
      o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + ")" if o.is_a?(Time)
      o = o._presentation if o.respond_to?(:_presentation)
      o
    end
    
    def pdf_link_update(object, attribute)
      # do absolutely nothing
    end
    
    #module ActionView::Helpers::DateHelper
    #
    #  def distance_of_time_in_words_to_now_with_future(from_time, include_seconds = false)
    #    if from_time > Time.now()
    #      'in ' + distance_of_time_in_words_to_now_without_future(from_time, include_seconds)
    #    else
    #      distance_of_time_in_words_to_now_without_future(from_time, include_seconds) + ' ago'
    #    end
    #  end
    #
    #  alias_method_chain :distance_of_time_in_words_to_now, :future
    #
    #end
    #
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
