require ('inline_forms/version.rb')
# InlineForms is a Rails Engine that let you setup an admin interface quick and
# easy. Please install it as a gem or include it in your Gemfile.
module InlineForms
  # DEFAULT_COLUMN_TYPES holds the standard ActiveRecord::Migration column types.
  # This list provides compatability with the standard types, but we add our own
  # later in 'Special Column Types'.
  #
  # These types will override Special Column Types of the same name.\
  #
  # Example:
  # rails g inline_forms Example name:string price:integer
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

  # DEFAULT_FORM_ELEMENTS holds a mapping from Default Column Types to
  # Form Elements. Form Elements are defined in lib/app/helpers/form_elements
  # and are pieces of code that display a form for a field.
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

  # SPECIAL_COLUMN_TYPES maps the column types that we define here and in
  # lib/app/helpers/form_elements to the standard ActiveRecord::Migration column
  # types
  #
  # Example: in lib/app/helpers/form_elements/dropdown.rb
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
  
  # RELATIONS defines a mapping between AR::Migrations columns and the Model.
  #
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

  # SPECIAL_RELATIONS maps AR relations to migrations.
  # In most cases, these relations have no migration at all, but they do need
  # a line in the model.
  SPECIAL_RELATIONS = {
    :has_many                 => :no_migration,
    :has_many_destroy         => :no_migration,
    :has_one                  => :no_migration,
    :has_and_belongs_to_many  => :no_migration,
    :habtm                    => :no_migration,
  }

  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #

  # Declare as a Rails::Engine, see http://www.ruby-forum.com/topic/211017#927932
  class Engine < Rails::Engine
    paths["app"] << "lib/app"
    paths["app/controllers"] << "lib/app/controllers"
    paths["app/helpers"] << "lib/app/helpers"
    paths["app/models"] << "lib/app/models"
    paths["app/views"] << "lib/app/views"
    paths["app/assets"] << "lib/app/assets"
  end

 


end

# make the current method and the calling method available
#   http://www.ruby-forum.com/topic/75258
#   supposedly, this is fixed in 1.9
module Kernel
  private
  def this_method
    caller[0] =~ /`([^']*)'/ and $1
  end
  def calling_method
    caller[1] =~ /`([^']*)'/ and $1
  end
end
