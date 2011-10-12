puts "loading inline_forms...#{InlineForms.VERSION}"

module InlineForms

  # ActiveRecord::Migration comes with a set of column types.
  # They are listed here so they can be used alongside our Special Column Types.
  #
  # These types will override the Special Column Types, so don't declare
  # types with these names as Special Column Types!
  #
  # Example:
  #  rails g inline_forms Example name:string price:integer
  # will result in:
  #   class InlineFormsCreateExamples < ActiveRecord::Migration
  #     def self.up
  #       create_table :examples do |t|
  #         t.string  :name
  #         t.integer :price
  #         t.timestamps
  #       end
  #     end
  #     def self.down
  #       drop_table :examples
  #     end
  #   end
  #
  DEFAULT_COLUMN_TYPES = {
    :string     => :string,
    :text       => :text,
    :integer    => :integer,
    :float      => :float,
    :decimal    => :decimal,
    :datetime   => :datetime,
    :timestamp  => :timestamp,
    :time       => :time,
    :date       => :date,
    :binary     => :binary,
    :boolean    => :boolean,
    # :references => :belongs_to,
    # :belongs_to => :belongs_to,
  }

  # For each Default Column Type, we need to specify a Form Element for use in form creation.
  #
  # Example:
  #  rails g inline_forms Example name:string price:integer
  # will result in the following model:
  #
  #    class Example < ActiveRecord::Base
  #      def inline_forms_attribute_list
  #        {
  #          :name  => [ "name", :text_field ],
  #          :price => [ "price", :text_field ],
  #        }
  #      end
  #    end
  # as you see, both :string and :integer are mapped to a :text_field
  #
  DEFAULT_FORM_ELEMENTS = {
    :string     => :text_field,
    :text       => :text_area,
    :integer    => :text_field,
    :float      => :text_field,
    :decimal    => :text_field,
    :datetime   => :datetime_select,
    :timestamp  => :datetime_select,
    :time       => :time_select,
    :date       => :date_select,
    :binary     => :text_field,
    :boolean    => :check_box,
  }

  # This Hash will be used to map our Special Column Types to
  # ActiveRecord::Migration Column Types.
  #
  # The helpers in app/helpers/form_elements add to this Hash.
  #
  # Usage example: in app/helpers/form_elements/dropdown.rb
  #  InlineForms::SPECIAL_COLUMN_TYPES[:dropdown]=:belongs_to
  # this maps the :dropdown form element to the :belongs_to column type.
  #
  # If you call the generator with country:dropdown, it will add
  #   t.belongs_to :country
  # to the migration. (In fact AR will add t.integer :country_id). And
  # it will add
  #   :country => [ "country", :dropdown ],
  # to the inline_forms_attribute_list in the model.
  #
  SPECIAL_COLUMN_TYPES = {
    :associated => :no_migration
  }
  # When a column has the type of :references or :belongs_to, then
  # there will be a line in the migration reflecting that, but not in the model.
  # == Why?
  # * Let's say we have a customer that has_many phone_numbers.
  # * Let's say that a phone_number belongs_to a customer.
  # * Let's say that every number has_one type_of_number (like 'private','gsm' etc.)
  # * Let's say a type_of_number belongs_to a number.
  #
  # Wait a minute... thats sounds right... but it ain't!
  #
  # In fact, a type_of_number has_many phone_numbers and a phone_number belongs_to a type_of_number!
  #
  # In a form, it's quite logical to use a dropdown for type_of_number. So, in the generator, use
  #  type_of_number:dropdown
  # This creates the correct migration (t.integer :type_of_number_id) and the correct model.
  # (It adds 'belongs_to :type_of_number' and adds a dropdown in the inline_forms_attribute_list)
  #
  # But, you also want to have a client_id in the migration, and a 'belongs_to :client' in the model.
  # In such cases, you need to use :belongs_to, like this:
  #  rails g inline_forms Example phone_number:string type_of_number:dropdown client:belongs_to
  #
  RELATIONS = {
    :belongs_to => :belongs_to,
    :references => :belongs_to,
  }

  # The stuff in this hash will add a line to the model, but little else.
  SPECIAL_RELATIONS = {
    :has_many                 => :no_migration,
    :has_many_destroy         => :no_migration,
    :has_one                  => :no_migration,
    :has_and_belongs_to_many  => :no_migration,
    :habtm                    => :no_migration,
  }

  # Declare as a Rails::Engine, see http://www.ruby-forum.com/topic/211017#927932
  class InlineFormsEngine < Rails::Engine
    initializer 'inline_forms.helper' do |app|
      ActionView::Base.send :include, InlineFormsHelper
    end
  end
end

