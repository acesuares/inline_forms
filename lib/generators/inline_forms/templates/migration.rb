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
#The types supported by Active Record are :primary_key, :string, :text, :integer, :float, :decimal, :datetime, :timestamp, :time, :date, :binary, :boolean
