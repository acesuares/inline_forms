puts 'loading inline_forms...'

module InlineForms
  # put the standard types in the list. new form_elements in app/helpers/form_elelemnts add to this.
  STANDARD_MIGRATION_COLUMN_TYPES = {
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
  MIGRATION_TYPE_CONVERSION_LIST = {}
  
  class InlineFormsEngine < Rails::Engine
    initializer 'inline_forms.helper' do |app|
      ActionView::Base.send :include, InlineFormsHelper
    end
  end
end
# http://www.ruby-forum.com/topic/211017#927932
