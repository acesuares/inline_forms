module InlineFormsHelper
    InlineForms::SPECIAL_MIGRATION_TYPES[:date_select]=:date

  # date
  def date_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def date_edit(object, attribute, values)
    calendar_date_select_tag attribute, object[attribute], :year_range => 30.years.ago..5.years.from_now, :popup => :force
  end
  def date_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end
end

