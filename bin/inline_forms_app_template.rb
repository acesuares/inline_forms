say "- Working directory is now #{`pwd`}"
say "- RVM gemset is now #{%x[rvm current]}"
  
gem 'rails', '3.2.12'
gem 'rake', '10.0.4'
gem 'jquery-rails', '~> 2.3.0'
gem 'jquery-ui-rails'
gem 'capistrano'
gem 'will_paginate', :git => 'git://github.com/acesuares/will_paginate.git'
gem 'tabs_on_rails', :git => 'git://github.com/acesuares/tabs_on_rails.git', :branch => 'update_remote'
gem 'ckeditor', :git => 'git://github.com/acesuares/ckeditor.git', :branch => 'master'
gem 'cancan', :git => 'git://github.com/acesuares/cancan.git', :branch => '2.0'
gem 'carrierwave'
gem 'remotipart', '~> 1.0'
gem 'paper_trail'
gem 'devise'
gem 'inline_forms'
gem 'validation_hints'
gem 'mini_magick'
gem 'jquery-ui-rails'
gem 'yaml_db'
gem 'rails-i18n'
gem 'i18n-active_record', :git => 'git://github.com/acesuares/i18n-active_record.git'
gem 'unicorn'
gem 'rvm'
gem 'rvm-capistrano'

group :development do
  gem 'sqlite3'
  gem 'rspec-rails'
  gem 'shoulda', '>= 0'
  gem 'bundler'
  gem 'jeweler'
end

group :production do
  gem 'mysql2'
  gem 'therubyracer'
  gem 'uglifier', '>= 1.0.3'
end

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  gem 'compass-rails' # you need this or you get an err
  gem 'zurb-foundation', '~> 4.0.0'
end 
