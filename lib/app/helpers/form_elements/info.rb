# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def info_show(object, attribute)
  # show the attribute. if it's a date/time, make it nicer. If it has a _presentation, show that instead
  o = object.send(attribute)
  o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + ")" if o.is_a?(Time)
  o = o._presentation if o.respond_to?(:_presentation)
  o
end

def info_edit(object, attribute)
  o = object.send(attribute)
  o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + ")" if o.is_a?(Time)
  o = o._presentation if o.respond_to?(:_presentation)
  o
end

def info_update(object, attribute)
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

