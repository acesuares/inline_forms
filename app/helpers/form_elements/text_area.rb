# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:text_area]=:text

def text_area_show(object, attribute)
  plain_text_show(object, attribute)
end

def text_area_edit(object, attribute)
  plain_text_edit(object, attribute)
end

def text_area_update(object, attribute)
  plain_text_update(object, attribute)
end

def text_area_info(object, attribute)
  plain_text_info(object, attribute)
end
