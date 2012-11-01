# -*- encoding : utf-8 -*-
InlineForms::SPECIAL_COLUMN_TYPES[:money_field]=:integer

def money_field_show(object, attribute)
  link_to_inline_edit object, attribute.to_sym, humanized_money_with_symbol(object.send attribute.to_sym)
end

def money_field_edit(object, attribute)
  text_field_tag attribute, (object.send attribute), :class => 'input_money_field'
end

def money_field_update(object, attribute)
  object.send(attribute + "=", params[attribute])
end

