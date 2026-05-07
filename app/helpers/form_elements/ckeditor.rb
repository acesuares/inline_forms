# -*- encoding : utf-8 -*-
# Legacy type name: CKEditor is removed; behaves like :rich_text.
InlineForms::SPECIAL_COLUMN_TYPES[:ckeditor]=:text

def ckeditor_show(object, attribute)
  rich_text_show(object, attribute)
end

def ckeditor_edit(object, attribute)
  rich_text_edit(object, attribute)
end

def ckeditor_update(object, attribute)
  rich_text_update(object, attribute)
end
