# -*- encoding : utf-8 -*-
# not needed here, since this is only used in the views InlineForms::SPECIAL_COLUMN_TYPES[:header]=:string

def header_show(object, attribute)
  # show the header which is the translated fake attribute
  attribute
end

def header_edit(object, attribute)
  # just show the header
  attribute
end

def header_update(object, attribute)
  # do absolutely nothing
end

