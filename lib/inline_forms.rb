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
  # Form Elements. Form Elements are defined in app/helpers/form_elements
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
  # app/helpers/form_elements to the standard ActiveRecord::Migration column
  # types
  #
  # Example: in app/helpers/form_elements/dropdown.rb
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
  INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"
  Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
    require form_element
  end

  private

  def inline_forms_version
    InlineForms::VERSION
  end

  # close link
  def close_link( object, update_span )
    link_to image_tag(  'close.png',
      :class => "close_icon",
      :title => 'close' ),
      send( object.class.to_s.underscore + '_path',
      object,
      :update => update_span,
      :close => true ),
      :remote => true
  end

  # destroy link
  def link_to_destroy( msg, object, update_span )
    if cancan_disabled? || ( can? :destroy, object )
      link_to image_tag(  'trash.png',
        :class => "trash_icon",
        :title => 'trash' ),
        send( object.class.to_s.underscore + '_path',
        object,
        :update => update_span ),
        :method => :delete,
        :remote => true
    end
  end

  def link_to_undo_destroy(msg, object, update_span )
    link_to("undo", revert_version_path(object.versions.scoped.last), :method => :post)
  end



  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value='')
    attribute_value = h(attribute_value)
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;".html_safe * spaces
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    if cancan_disabled? || ( can? :update, object )
      link_to attribute_value,
        send( 'edit_' + object.class.to_s.underscore + '_path',
        object,
        :attribute => attribute.to_s,
        :form_element => calling_method.sub(/_[a-z]+$/,''),
        :update => css_class_id ),
        :remote => true
    else
      attribute_value
    end
  end

  def link_to_new_record(text, model, path_to_new, update_span, parent_class, parent_id)
    out = ""
    out << "<li class='new_record_link'>"
    out << (link_to text, send(path_to_new, :update => update_span, :parent_class => parent_class, :parent_id => parent_id ), :remote => true)
    out << "</li>"
    ""
    if cancan_enabled?
      if can?(:create, model.constantize)
        if parent_class.nil?
          raw out
        else
          raw out if can?(:update, parent_class.find(parent_id))
        end
      end
    else
      raw out
    end
  end

  # get the values for an attribute
  #
  # values should be a Hash { integer => string, ... }
  #
  # or a one-dimensional array of strings
  #
  # or a Range
  #
  def attribute_values(object, attribute)
    # if we have a range 1..6  will result in [[0,1],[1,2],[2,3],...,[5,6]]
    # or range -3..3 will result in [[0,-3],[1,-2],[2,-1],...,[6,3]]
    # if we have an array ['a','d','b'] will result in [[0,'a'],[2,'b'],[1,'d']] (sorted on value)
    # if we have a hash { 0=>'a', 2=>'b', 3=>'d' } will result in [[0,'a'],[2,'b'],[3,'d']] (it will keep the index and sort on the index)
    # TODO work this out better!
    values = object.inline_forms_attribute_list.assoc(attribute.to_sym)[3]
    raise "No Values defined in #{@Klass}, #{attribute}" if values.nil?
    if values.is_a?(Hash)
      temp = Array.new
      values.to_a.each do |k,v|
        temp << [ k, v ]
      end
      values = temp.sort {|a,b| a[0]<=>b[0]}
    else
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, values.to_a[i] ]
      end
      values = temp.sort {|a,b| a[1]<=>b[1]}
    end
    values
  end

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



