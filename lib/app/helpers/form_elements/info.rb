# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:info]=:string

def info_show(object, attribute)
  object.send(attribute)
end

def info_edit(object, attribute)
  object[attribute]
end

def info_update(object, attribute)
end

