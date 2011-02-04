class <%= name %> < ActiveRecord::Base

  def presentation
    #define your presentation here
  end

  def inline_forms_field_list
  [
  <% for attribute in attributes %>
     [ :<%= attribute.migration_type %>, '<%= attribute.name %>', :<%= attribute.field_type %> ],
  <% end %>
  ]
end
end