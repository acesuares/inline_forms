# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def info_show(object, attribute)
  o = object.send attribute.to_sym
  o = o.to_s + " (" + distance_of_time_in_words_to_now(o) + " ago )" if o.is_a?(Time)
  o
end

#def info_edit(object, attribute)
#  object[attribute]
#end
#
#def info_update(object, attribute)
#end
#
