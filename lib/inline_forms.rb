# -*- encoding : utf-8 -*-

require "inline_forms/version"
require "inline_forms/attribute_list"
require "inline_forms/form_element_from_callee"
require "inline_forms/archived_form_elements"
require "inline_forms/form_element_registry"
require "inline_forms/form_elements"
require "inline_forms/tabs"
require "inline_forms/turbo_tabs_builder"
# InlineForms is a Rails Engine that let you setup an admin interface quick and
# easy. Please install it as a gem or include it in your Gemfile.
module InlineForms
  class PlainTextColumnMissingError < StandardError; end

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
    string: :string,
    text: :text,
    integer: :integer,
    float: :float,
    decimal: :decimal,
    datetime: :datetime,
    timestamp: :timestamp,
    time: :time,
    date: :date,
    binary: :binary,
    boolean: :boolean
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
  #    class Example < ApplicationRecord
  #      def inline_forms_attribute_list
  #        [
  #          [ :name,  :text_field ],
  #          [ :price, :text_field ],
  #        ]
  #      end
  #    end
  # as you see, both :string and :integer are mapped to a :text_field
  #
  DEFAULT_FORM_ELEMENTS = {
    string: :text_field,
    text: :plain_text,
    integer: :text_field,
    float: :text_field,
    decimal: :text_field,
    datetime: :datetime_select,
    timestamp: :datetime_select,
    time: :time_select,
    date: :date_select,
    binary: :text_field,
    boolean: :check_box
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
  #   [ :country, :dropdown ],
  # to the inline_forms_attribute_list in the model.
  #
  SPECIAL_COLUMN_TYPES = {
    associated: :no_migration
  }

  PLAIN_TEXT_FORM_ELEMENTS = %i[
    plain_text
    plain_text_area
  ].freeze

  def self.plain_text_form_element?(form_element)
    PLAIN_TEXT_FORM_ELEMENTS.include?(form_element.to_sym)
  rescue NoMethodError
    false
  end

  def self.assert_plain_text_column!(object:, attribute:, form_element:)
    return unless plain_text_form_element?(form_element)
    return if object.class.column_names.include?(attribute.to_s)

    raise PlainTextColumnMissingError,
      "#{object.class.name}##{attribute} uses #{form_element} but has no DB column `#{attribute}`. " \
      "Use :rich_text for ActionText-backed attributes, or add a text column for :plain_text."
  end

  def self.validate_plain_text_configuration_for!(klass)
    return unless klass.respond_to?(:table_exists?) &&
                  klass.respond_to?(:column_names) &&
                  klass.instance_methods.include?(:inline_forms_attribute_list)
    return unless klass.table_exists?

    attributes = klass.new.inline_forms_attribute_list
    attributes.each do |attribute, form_element|
      next unless plain_text_form_element?(form_element)
      next if klass.column_names.include?(attribute.to_s)

      raise PlainTextColumnMissingError,
        "#{klass.name} inline_forms_attribute_list declares #{attribute}:#{form_element}, " \
        "but table `#{klass.table_name}` has no `#{attribute}` column. " \
        "Use :rich_text for ActionText-backed attributes."
    end
  end

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
    belongs_to: :belongs_to,
    references: :belongs_to
  }

  # SPECIAL_RELATIONS maps AR relations to migrations.
  # In most cases, these relations have no migration at all, but they do need
  # a line in the model.
  SPECIAL_RELATIONS = {
    has_many: :no_migration,
    has_many_destroy: :no_migration,
    has_one: :no_migration,
    has_and_belongs_to_many: :no_migration,
    habtm: :no_migration
  }

  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #

  # Declare as a Rails::Engine, see http://www.ruby-forum.com/topic/211017#927932
  class Engine < Rails::Engine
    initializer "inline_forms.form_element_registry" do
      InlineForms::FormElementRegistry.apply!
    end

    initializer "inline_forms.form_element_helpers" do
      InlineForms::FormElements.load_helpers!
    end

    initializer "inline_forms.ignore_form_element_autoload", before: :setup_autoloaders do
      path = root.join("lib/inline_forms/form_elements")
      Rails.autoloaders.main.ignore(path)
      Rails.autoloaders.once.ignore(path) if Rails.autoloaders.respond_to?(:once)
    end

    # validation_hints 6.x registers its ActiveModel patch via on_load, but apps
    # require rails/all before Bundler.require, so active_model is already loaded.
    initializer "inline_forms.validation_hints" do
      require "validation_hints"
      ValidationHints::ValidationsPatch.apply!
    end

    # Tabs support (set_tab / current_tab? / tabs_tag) is vendored in
    # InlineForms::Tabs since 8.1.23. Apps generated before 8.1.23 still bundle
    # the tabs_on_rails gem, whose Railtie includes the identical API into
    # ActionController::Base — skip ours then so the two don't stack.
    initializer "inline_forms.tabs" do
      ActiveSupport.on_load(:action_controller) do
        unless defined?(TabsOnRails::ActionController)
          ::ActionController::Base.include(InlineForms::Tabs::Controller)
        end
      end
    end

    initializer "inline_forms.assets.precompile" do |app|
      # Skip when the host has no Sprockets-style pipeline (e.g. the test/dummy
      # harness); generated apps always bundle sprockets-rails.
      next unless app.config.respond_to?(:assets)

      app.config.assets.precompile += %w[
        inline_forms/inline_forms.css
        inline_forms/devise.css
        inline_forms/inline_forms.js
        inline_forms_fonts.css
        popper.min.js
        tippy-bundle.umd.min.js
        trix.min.js
        trix.css
        inline_forms/glass_plate.gif
        foundation-icons.woff
        foundation-icons.ttf
        foundation-icons.svg
        opensans-v44-latin-regular.woff2
        opensans-v44-latin-italic.woff2
      ]
    end

    config.to_prepare do
      next unless defined?(ActiveRecord::Base)

      ActiveRecord::Base.descendants.each do |klass|
        begin
          InlineForms.validate_no_archived_form_elements_for!(klass)
          InlineForms.validate_plain_text_configuration_for!(klass)
        rescue InlineForms::PlainTextColumnMissingError, InlineForms::ArchivedFormElementError
          raise
        rescue StandardError
          # Some descendants might be abstract or temporarily unresolved while
          # the app boots/reloads; runtime checks in controllers still enforce
          # plain_text column presence for active resources.
        end
      end
    end

    I18n.load_path << Dir[File.join(File.expand_path(File.dirname(__FILE__) + "/locales"), "*.yml")]
    I18n.load_path.flatten!
  end
end
