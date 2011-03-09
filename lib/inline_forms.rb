puts 'loading inline_forms...'

module InlineForms
  # ActiveRecord::Migration comes with a set of column types.
  # They are listed here so they can be uses alongside our Special Column Types.
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
  #         t.string :name
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
    :string => :string,
    :text => :text,
    :integer => :integer,
    :float => :float,
    :decimal => :decimal,
    :datetime => :datetime,
    :timestamp => :timestamp,
    :time => :time,
    :date => :date,
    :binary => :binary,
    :boolean => :boolean,
#    :references => :belongs_to,
#    :belongs_to => :belongs_to,
  }
  # For each Default Column Type, we need to specify a Form Element for use in form creation.
  #
  # Example:
  #  rails g inline_forms Example name:string price:integer
  # will result in the following model:
  #
  #    class Example < ActiveRecord::Base
  #      def inline_forms_field_list
  #        [
  #          [ :name, "name", :text_field ],
  #          [ :price, "price", :text_field ],
  #        ]
  #      end
  #    end
  # as you see, both :string and :integer are mapped to a :text_field
  #
  DEFAULT_FORM_ELEMENTS = {
    :string => :text_field,
    :text => :text_area,
    :integer => :text_field,
    :float => :text_field,
    :decimal => :text_field,
    :datetime => :datetime_select,
    :timestamp => :datetime_select,
    :time => :time_select,
    :date => :date_select,
    :binary => :text_field,
    :boolean => :check_box,
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
  #   [ :country, "country", :dropdown ],
  # to the model.
  #
  SPECIAL_COLUMN_TYPES = {}
  # experimental
  RELATIONS = {
    :belongs_to => :belongs_to,
    :references => :belongs_to,
  }
  # experimental
  SPECIAL_RELATIONS = {
    :has_many   => :has_many,
    :associated => :associated,
  }
#    has_and_belongs_to_many :clients
#	def <=>(other)
#		self.name <=> other.name
#  end

  # Declare as a Rails::Engine, see http://www.ruby-forum.com/topic/211017#927932
  class InlineFormsEngine < Rails::Engine
    initializer 'inline_forms.helper' do |app|
      ActionView::Base.send :include, InlineFormsHelper
    end
  end
end

