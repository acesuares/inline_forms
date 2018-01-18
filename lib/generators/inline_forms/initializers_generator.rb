module InlineForms
  module Generators
    class InitializersGenerator < Rails::Generators::Base
      source_root File.expand_path('../../templates', __FILE__)

      desc 'Update css in main app from inline_forms file'
      def update_initializers
        remove_file 'config/initializers/paper_trail.rb'
        copy_file 'paper_trail.rb', 'config/initializers/paper_trail.rb'
      end
    end
  end
end
