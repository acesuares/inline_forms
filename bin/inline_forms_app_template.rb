say "- Working directory is now #{`pwd`}"
say "- RVM gemset is now #{%x[rvm current]}"
  
create_file 'Gemfile', '# created by inline_forms\n'
add_source 'https://rubygems.org'
gem 'rails', '3.2.12'
gem 'rake', '10.0.4'
gem 'jquery-rails', '~> 2.3.0'
gem 'jquery-ui-rails'
gem 'capistrano'
gem 'will_paginate', :git => 'git://github.com/acesuares/will_paginate.git'
gem 'tabs_on_rails', :git => 'git://github.com/acesuares/tabs_on_rails.git', :branch => 'update_remote'
gem 'ckeditor'
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

gem_group :development do
  gem 'sqlite3'
  gem 'rspec-rails'
  gem 'shoulda', '>= 0'
  gem 'bundler'
  gem 'jeweler'
end

gem_group :production do
  gem 'mysql2'
  gem 'therubyracer'
  gem 'uglifier', '>= 1.0.3'
end

gem_group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  gem 'compass-rails' # you need this or you get an err
  gem 'zurb-foundation', '~> 4.0.0'
end 

say "- Running bundle..."
run "bundle install"

say "- Database setup: creating config/database.yml with development database #{database}"
remove_file "config/database.yml" # the one that 'rails _3.2.12_ new' created
if using_sqlite?
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc_with_indent
  development:
    adapter: sqlite3
    database: db/development.sqlite3
    pool: 5
    timeout: 5000

  END_DATABASEYML
else
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc_with_indent
  development:
    adapter: mysql2
    database: #{app_name}_dev
    username: #{app_name}
    password: #{app_name}

  END_DATABASEYML
end
append_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc_with_indent
  production:
    adapter: mysql2
    database: #{app_name}_p
    username: #{app_name}
    password: #{app_name}444
END_DATABASEYML

say "- Devise install..."
run "bundle exec rails g devise:install"

say "- Devise User model install with added name and locale field..."
run "bundle exec rails g devise User name:string locale:string"

say "- Replace Devise route and add path_prefix..."
gsub_file "config/routes.rb", /devise_for :users/, "devise_for :users, :path_prefix => 'auth'"
insert_into_file "config/routes.rb", <<-ROUTE.strip_heredoc_with_indent(2), :after => "devise_for :users, :path_prefix => 'auth'\n"
  resources :users do
    post 'revert', :on => :member
  end
ROUTE

say "- Create User Controller..."
create_file "app/controllers/users_controller.rb", <<-USERS_CONTROLLER.strip_heredoc_with_indent
  class UsersController < InlineFormsController
    set_tab :user
  end
USERS_CONTROLLER

say "- Recreate User Model..."
remove_file "app/models/user.rb" # the one that 'devise:install' created
create_file "app/models/user.rb", <<-USER_MODEL.strip_heredoc_with_indent
  class User < ActiveRecord::Base

    # devise options
    devise :database_authenticatable
    # devise :registerable # uncomment this if you want people to be able to register
    devise :recoverable
    devise :rememberable
    devise :trackable
    devise :validatable
    # devise :token_authenticatable
    # devise :confirmable,
    # devise :lockable
    # devise :timeoutable
    # devise :omniauthable

    # Setup accessible (or protected) attributes for your model
    attr_accessible :email, :password, :password_confirmation, :remember_me, :name, :locale
    attr_writer :inline_forms_attribute_list

    # validations
    validates :name, :presence => true

    # pagination
    attr_reader :per_page
    @per_page = 7

    has_paper_trail

    def _presentation
      "\#{name}"
    end

    def inline_forms_attribute_list
      @inline_forms_attribute_list ||= [
        [ :name , 'name', :text_field ],
        [ :email , 'email', :text_field ],
        [ :password , 'Nieuw wachtwoord', :devise_password_field ],
        [ :encrypted_password , 'encrypted_password', :info ],
        [ :reset_password_token , 'reset_password_token', :info ],
        [ :reset_password_sent_at , 'reset_password_sent_at', :info],
        [ :remember_created_at , 'remember_created_at', :info ],
        [ :sign_in_count , 'sign_in_count', :info ],
        [ :current_sign_in_at , 'current_sign_in_at', :info ],
        [ :last_sign_in_at , 'last_sign_in_at', :info ],
        [ :current_sign_in_ip , 'current_sign_in_ip', :info ],
        [ :last_sign_in_ip , 'last_sign_in_ip', :info ],
        [ :created_at , 'created_at', :info ],
        [ :updated_at , 'updated_at', :info ],
      ]
    end

    def self.not_accessible_through_html?
      false
    end

    def self.order_by_clause
      'name'
    end

  end
USER_MODEL

say "- Install ckeditor..."
generate "ckeditor", "install"

say "- Mount Ckeditor::Engine to routes..."
route "mount Ckeditor::Engine => '/ckeditor'"

say "- Add ckeditor autoload_paths to application.rb..."
application "config.autoload_paths += %W(\#{config.root}/app/models/ckeditor)"

say "- Add ckeditor/init to application.js..."
insert_into_file "app/assets/javascripts/application.js",
                 "//= require ckeditor/init\n",
                 :before => "//= require_tree .\n"

say "- Create ckeditor config.js"
copy_file "lib/app/assets/javascripts/ckeditor/config.js", "app/assets/javascripts/ckeditor/config.js"

say "- Add remotipart to application.js..."
insert_into_file "app/assets/javascripts/application.js", "//= require jquery.remotipart\n", :before => "//= require_tree .\n"

say "- Paper_trail install..."
generate "paper_trail", "install"

say "- Installaing ZURB Foundation..."
generate "foundation", "install"

say "- Generate models and tables and views for translations..."
generate "inline_forms", "InlineFormsLocale name:string inline_forms_translations:belongs_to _enabled:yes _presentation:\#{name}"
generate "inline_forms", "InlineFormsKey name:string inline_forms_translations:has_many inline_forms_translations:associated _enabled:yes _presentation:\#{name}'"
generate "inline_forms", "InlineFormsTranslation inline_forms_key:belongs_to inline_forms_locale:dropdown value:text interpolations:text is_proc:boolean _presentation:\#{value}'"

sleep 1 # to get unique migration number
create_file "db/migrate/" + 
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "inline_forms_create_view_for_translations.rb", <<-VIEW_MIGRATION.strip_heredoc_with_indent
  class InlineFormsCreateViewForTranslations < ActiveRecord::Migration

    def self.up
      execute 'CREATE VIEW translations
               AS
                 SELECT L.name AS locale,
                        K.name AS thekey,
                        T.value AS value,
                        T.interpolations AS interpolations,
                        T.is_proc AS is_proc
                   FROM inline_forms_keys K, inline_forms_locales L, inline_forms_translations T
                     WHERE T.inline_forms_key_id = K.id AND T.inline_forms_locale_id = L.id '
    end

    def self.down
      execute 'DROP VIEW translations'
    end

  end
VIEW_MIGRATION

say "- Migrating Database (only when using sqlite)"
run "bundle exec rake db:migrate" if using_sqlite?

say "- Adding admin user with email: #{email}, password: #{password} to seeds.rb"
append_to_file "db/seeds.rb", "User.create({ :email => '#{email}', :name => 'Admin', :password => '#{password}', :password_confirmation => '#{password}'}, :without_protection => true)"

say "- Seeding the database (only when using sqlite)"
run "bundle exec rake db:seed" if using_sqlite?

say "- Creating header in app/views/inline_forms/_header.html.erb..."
create_file "app/views/inline_forms/_header.html.erb", <<-END_HEADER.strip_heredoc_with_indent
    <div id='Header'>
      <div id='title'>
        #{app_name} v<%= inline_forms_version -%>
      </div>
      <% if current_user -%>
      <div id='logout'>
        <%= link_to \"Afmelden: \#{current_user.name}\", destroy_user_session_path, :method => :delete %>
      </div>
      <% end -%>
      <div style='clear: both;'></div>
    </div>
END_HEADER

say "- Recreating ApplicationHelper to set application_name and application_title..."
remove_file "app/helpers/application_helper.rb" # the one that 'rails new' created
create_file "app/helpers/application_helper.rb", <<-END_APPHELPER.strip_heredoc_with_indent
  module ApplicationHelper
    def application_name
      '#{app_name}'
    end
    def application_title
      '#{app_name}'
    end
  end
END_APPHELPER

say "- Recreating ApplicationController to add devise, cancan, I18n stuff..."
remove_file "app/controllers/application_controller.rb" # the one that 'rails new' created
create_file "app/controllers/application_controller.rb", <<-END_APPCONTROLLER.strip_heredoc_with_indent
  class ApplicationController < InlineFormsApplicationController
    protect_from_forgery

    # Comment next two lines if you don't want Devise authentication
    before_filter :authenticate_user!
    layout 'devise' if :devise_controller?

    # Comment next 6 lines if you want CanCan authorization
    enable_authorization :unless => :devise_controller?

    rescue_from CanCan::Unauthorized do |exception|
      sign_out :user if user_signed_in?
      redirect_to new_user_session_path, :alert => exception.message
    end

    # Uncomment next line if you want I18n (based on subdomain)
    # before_filter :set_locale

    # Uncomment next line and specify default locale
    # I18n.default_locale = :en

    # Uncomment next line and specify available locales
    # I18n.available_locales = [ :en, :nl, :pp ]

    # Uncomment next nine line if you want locale based on subdomain, like 'it.example.com, de.example.com'
    # def set_locale
    #   I18n.locale = extract_locale_from_subdomain || I18n.default_locale
    # end
    #
    # def extract_locale_from_subdomain
    #   locale = request.subdomains.first
    #   return nil if locale.nil?
    #   I18n.available_locales.include?(locale.to_sym) ? locale.to_s : nil
    # end
  end
END_APPCONTROLLER

say "- Creating Ability model so that the user with id = 1 can access all..."
create_file "app/models/ability.rb", <<-END_ABILITY.strip_heredoc_with_indent
  class Ability
    include CanCan::Ability

    def initialize(user)
      # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities

      user ||= user.new # guest user

      if user.id == 1 #quick hack
        can :access, :all
      else
        # put restrictions for other users here
      end
    end
  end
END_ABILITY

