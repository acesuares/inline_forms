# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def info_show(object, attribute)
  # show the attribute. if it's a date/time, make it nicer. If it has a _presentation, show that instead
  o = object.send(attribute)
  o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + " ago )" if o.is_a?(Time)
  o = o._presentation if o.respond_to?(:_presentation)
  o
end

def info_edit(object, attribute)
  o = object.send(attribute)
  o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + " ago )" if o.is_a?(Time)
  o = o._presentation if o.respond_to?(:_presentation)
  o
end

def info_update(object, attribute)
  # do absolutely nothing
end

