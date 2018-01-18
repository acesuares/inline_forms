module InlineForms
  module Generators
    class StylesheetsGenerator < Rails::Generators::Base
      source_root File.expand_path('../../assets', __FILE__)

      desc 'Update css in main app from inline_forms file'
      def update_css
        remove_file 'app/assets/stylesheets/inline_forms.scss'
        copy_file 'stylesheets/inline_forms.scss', 'app/assets/stylesheets/inline_forms.scss'
      end
    end
  end
end
