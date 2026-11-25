# -*- encoding : utf-8 -*-
module InlineForms
  module FormElements
    module InfoHelper
      module_eval(<<~'INLINE_FORMS_FORM_ELEMENT', __FILE__, __LINE__ + 1)
    # -*- encoding : utf-8 -*-
    
    def info_show(object, attribute)
      # show the attribute. if it's a date/time, make it nicer. If it has a _presentation, show that instead
      o = object.send(attribute)
      o = info_time_or_date_text(o)
      o = o._presentation if o.respond_to?(:_presentation)
      o
    end
    
    def info_edit(object, attribute)
      o = object.send(attribute)
      o = info_time_or_date_text(o)
      o = o._presentation if o.respond_to?(:_presentation)
      o
    end
    
    # A time (Time, TimeWithZone or DateTime) as the versions panel shows it,
    # with how long ago; a Date as dd-mm-yyyy. A DateTime used to print raw
    # ("2026-11-24 22:13:13 UTC"): it is a Date, not a Time.
    def info_time_or_date_text(o)
      case o
      when Time, DateTime, ActiveSupport::TimeWithZone
        "#{inline_forms_time_text(o)} (#{distance_of_time_in_words_to_now(o)})"
      when Date then o.strftime(InlineForms::DATE_FORMAT)
      else o
      end
    end

    def info_update(object, attribute)
      # do absolutely nothing
    end
    
    def info_info(object, attribute)
      # show the attribute. if it's a date/time, make it nicer. If it has a _presentation, show that instead
      o = object.send(attribute)
      o = info_time_or_date_text(o)
      o = o._presentation if o.respond_to?(:_presentation)
      o
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
      INLINE_FORMS_FORM_ELEMENT
    end
  end
end
