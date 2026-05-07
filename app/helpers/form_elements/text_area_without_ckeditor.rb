# -*- encoding : utf-8 -*-
# Legacy alias for plain :text_area (CKEditor removed).
InlineForms::SPECIAL_COLUMN_TYPES[:text_area_without_ckeditor]=:text

def text_area_without_ckeditor_show(object, attribute)
  plain_text_show(object, attribute)
end

def text_area_without_ckeditor_edit(object, attribute)
  plain_text_edit(object, attribute)
end

def text_area_without_ckeditor_update(object, attribute)
  plain_text_update(object, attribute)
end

def text_area_without_ckeditor_info(object, attribute)
  plain_text_info(object, attribute)
end
