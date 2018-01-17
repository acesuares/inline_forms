module InlineForms
  module Generators
    class StylesheetsGenerator < Rails::Generators::Base
      source_root File.expand_path('../stylesheets', __FILE__)

      desc 'Update css in main app from inline_forms file'
      def update_css
        remove_file 'app/assets/stylesheeets/inline_forms.scss'
        copy_file 'inline_forms.scss', 'app/assets/stylesheeets/inline_forms.scss'
      end
    end
  end
end
