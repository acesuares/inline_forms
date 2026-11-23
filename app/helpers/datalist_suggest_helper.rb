# A text field with the browser's own suggestion list (<datalist>), filled by
# app/assets/javascripts/inline_forms/datalist_suggest.js from `url` (JSON)
# while the user types. Replaces rails-jquery-autocomplete's
# `autocomplete_field_tag`:
#
#   <%= suggest_field_tag "search", params[:search], autocomplete_member_last_name_members_path, placeholder: "achternaam" %>
#
# Two fields with the same name on one page: give each its own `list:` id.
#
# The same module, with the same name, as the copies some apps have in their
# own app/helpers: an app's file wins over this one.
module DatalistSuggestHelper
  def suggest_field_tag(name, value, url, options = {})
    options = options.dup
    list_id = options.delete(:list) || "#{name.to_s.gsub(/[^-a-zA-Z0-9:.]/, '_')}_suggestions"
    data = (options.delete(:data) || {}).merge(suggest_url: url)
    field = text_field_tag(name, value, options.merge(list: list_id, autocomplete: "off", data: data))
    safe_join([ field, content_tag(:datalist, "", id: list_id) ])
  end
end
