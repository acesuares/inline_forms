puts 'loading inline_forms...'

module InlineForms
  class InlineFormsEngine < Rails::Engine
      initializer 'inline_forms.helper' do |app|
            ActionView::Base.send :include, InlineFormsHelper
                end
                  end
                  end
# http://www.ruby-forum.com/topic/211017#927932
