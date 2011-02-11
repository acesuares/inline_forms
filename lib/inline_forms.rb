puts 'loading inline_forms...'

module InlineForms
  # convert type to migration_type
  DEFAULT_MIGRATION_TYPES = {
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
  }
  # convert type to field_type
  DEFAULT_FIELD_TYPES = {
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
  # define this so the helpers can add to it
  SPECIAL_MIGRATION_TYPES = {}
  # experimental
  RELATION_TYPES = {
    :belongs_to => :integer,
  }
  SPECIAL_RELATION_TYPES = {
    :associated => :associated,
  }
  
  class InlineFormsEngine < Rails::Engine
    initializer 'inline_forms.helper' do |app|
      ActionView::Base.send :include, InlineFormsHelper
    end
  end
end
# http://www.ruby-forum.com/topic/211017#927932
