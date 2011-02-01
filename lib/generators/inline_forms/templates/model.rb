class <%= name %> < ActiveRecord::Base

  def presentation
    #define your presentation here
  end

  def inline_forms_field_list
  [
  <% for attribute in attributes -%>
     [ '<%= attribute.name %>', :<%= attribute.name %>, '<%= attribute.type %>' ]
  <% end -%>
  ]
  end
end
