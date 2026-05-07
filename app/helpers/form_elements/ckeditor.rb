# -*- encoding : utf-8 -*-
# Legacy type name: CKEditor is removed; behaves like :text_area.
InlineForms::SPECIAL_COLUMN_TYPES[:ckeditor]=:text

def ckeditor_show(object, attribute)
  text_area_show(object, attribute)
end

def ckeditor_edit(object, attribute)
  text_area_edit(object, attribute)
end

def ckeditor_update(object, attribute)
  text_area_update(object, attribute)
end
