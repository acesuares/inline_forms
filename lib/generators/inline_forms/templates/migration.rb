class InlineFormsCreate<%= table_name.camelize %> < ActiveRecord::Migration
  def self.up
    create_table :<%= table_name %> do |t|
  <% for attribute in attributes -%>
      t.<%= attribute.migration_type %> :<%= attribute.name %>
  <% end -%>
      t.timestamps
    end
end

def self.down
  drop_table :<%= table_name %>
  end
end
