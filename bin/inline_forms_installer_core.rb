GENERATOR_PATH = File.dirname(File.expand_path(__FILE__)) +  '/../'

create_file 'Gemfile', "# created by inline_forms #{ENV['inline_forms_version']}\n"

add_source 'https://rubygems.org'

gem 'rails', '~> 3.2.21'
gem 'rake'
gem 'jquery-rails'
gem 'jquery-ui-sass-rails'
gem 'capistrano'
gem 'will_paginate', :git => 'git://github.com/acesuares/will_paginate.git'
gem 'tabs_on_rails', :git => 'git://github.com/acesuares/tabs_on_rails.git', :branch => 'update_remote'
gem 'ckeditor'
gem 'cancan', :git => 'git://github.com/acesuares/cancan.git', :branch => '2.0'
gem 'carrierwave'
gem 'remotipart', '~> 1.0'
gem 'paper_trail'
gem 'devise'
gem 'inline_forms', '~> 3.0'
gem 'validation_hints'
gem 'mini_magick'
gem 'rails-i18n'
gem 'i18n-active_record', :git => 'git://github.com/acesuares/i18n-active_record.git'
gem 'unicorn'
gem 'rvm'
gem 'rvm-capistrano', require: false
gem 'foundation-rails'
gem 'mysql2'


gem_group :development do
  gem 'yaml_db'
  gem 'seed_dump', git: 'git://github.com/acesuares/seed_dump.git'
  gem 'switch_user'
  gem 'sqlite3'
  gem 'rspec-rails'
  gem 'shoulda'
  gem 'bundler'
  gem 'jeweler'
  gem 'capybara'
  gem 'factory_girl'
  gem 'factory_girl_rails'
  gem 'rspec'
  gem 'turbo-sprockets-rails3'
end

gem_group :production do
  gem 'therubyracer'
  gem 'uglifier'
end

gem_group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'compass-rails'
  gem 'foundation-icons-sass-rails'
end

say "- Running bundle..."
run "bundle install"

say "- Database setup: creating config/database.yml with development database #{ENV['database']}"
remove_file "config/database.yml" # the one that 'rails _3.2.21_ new' created
if ENV['using_sqlite'] == 'true'
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  development:
    adapter: sqlite3
    database: db/development.sqlite3
    pool: 5
    timeout: 5000

  END_DATABASEYML
else
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  development:
    adapter: mysql2
    database: #{app_name}_dev
    username: #{app_name}
    password: #{app_name}

  END_DATABASEYML
end
append_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  production:
    adapter: mysql2
    database: #{app_name}_prod
    username: #{app_name}
    password: #{app_name}444
END_DATABASEYML

say "- Devise install..."
run "bundle exec rails g devise:install"

say "- Create Devise route and add path_prefix..."

route <<-ROUTE.strip_heredoc
devise_for :users, :path_prefix => 'auth'
  resources :users do
    post 'revert', :on => :member
end
ROUTE

say "- Create devise migration file"

sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "devise_create_users.rb", <<-DEVISE_MIGRATION.strip_heredoc
class DeviseCreateUsers < ActiveRecord::Migration

  def change
    create_table(:users) do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      # t.string   :confirmation_token
      # t.datetime :confirmed_at
      # t.datetime :confirmation_sent_at
      # t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      # t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      # t.string   :unlock_token # Only if unlock strategy is :email or :both
      # t.datetime :locked_at

      t.string :name
      t.integer :locale_id

      t.timestamps
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    # add_index :users, :confirmation_token,   unique: true
    # add_index :users, :unlock_token,         unique: true
  end
end
DEVISE_MIGRATION

say "- Create User Controller..."
create_file "app/controllers/users_controller.rb", <<-USERS_CONTROLLER.strip_heredoc
  class UsersController < InlineFormsController
    set_tab :user
  end
USERS_CONTROLLER

say "- Create User Model..."
create_file "app/models/user.rb", <<-USER_MODEL.strip_heredoc
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
    attr_writer :inline_forms_attribute_list
    attr_accessible :email, :password, :locale, :remember_me

    belongs_to :locale
    has_and_belongs_to_many :roles

    # validations
    validates :name, :presence => true

    default_scope order :name

    # pagination
    attr_reader :per_page
    @per_page = 7

    has_paper_trail

    def _presentation
      "\#{name}"
    end

    def role?(role)
      return !!self.roles.find_by_name(role)
    end

    def inline_forms_attribute_list
      @inline_forms_attribute_list ||= [
        [ :header_user_login,         '', :header ],
        [ :name,                      '', :text_field ],
        [ :email,                     '', :text_field ],
        [ :locale ,                   '', :dropdown ],
        [ :password,                  '', :devise_password_field ],
        [ :header_user_roles,         '', :header ],
        [ :roles,                     '', :check_list ],
        [ :header_user_other_stuff,   '', :header ],
        [ :encrypted_password,        '', :info ],
        [ :reset_password_token,      '', :info ],
        [ :reset_password_sent_at,    '', :info],
        [ :remember_created_at,       '', :info ],
        [ :sign_in_count,             '', :info ],
        [ :current_sign_in_at,        '', :info ],
        [ :last_sign_in_at,           '', :info ],
        [ :current_sign_in_ip,        '', :info ],
        [ :last_sign_in_ip,           '', :info ],
        [ :created_at,                '', :info ],
        [ :updated_at,                '', :info ],
      ]
    end

    def self.not_accessible_through_html?
      false
    end

    def self.order_by_clause
      nil
    end

  end
USER_MODEL

say "- Adding admin user with email: #{ENV['email']}, password: #{ENV['password']} to seeds.rb"
append_to_file "db/seeds.rb", "User.create({ id: 1, email: '#{ENV['email']}', locale_id: 1, name: 'Admin', password: '#{ENV['password']}', password_confirmation: '#{ENV['password']}' }, without_protection: true)\n"

# Create Locales
say "- Create locales"
generate "inline_forms", "Locale name:string title:string users:has_many _enabled:yes _presentation:\#{title}"
append_to_file "db/seeds.rb", "Locale.create({ id: 1, name: 'en', title: 'English' }, without_protection: true)\n"

# Create Roles
say "- Create roles"
generate "inline_forms", "Role name:string description:text users:has_and_belongs_to_many _enabled:yes _presentation:\#{name}"
sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "inline_forms_create_join_table_user_role.rb", <<-ROLES_MIGRATION.strip_heredoc
  class InlineFormsCreateJoinTableUserRole < ActiveRecord::Migration
    def self.up
      create_table  :roles_users, :id => false, :force => true do |t|
        t.integer   :role_id
        t.integer   :user_id
      end
      execute 'INSERT INTO roles_users VALUES (1,1);'
    end

    def self.down
      drop_table roles_users
    end
  end
ROLES_MIGRATION

append_to_file "db/seeds.rb", "Role.create({ id: 1, name: 'superadmin', description: 'Super Admin can access all.' }, without_protection: true)\n"

say "- Installaing ZURB Foundation..."
generate "foundation:install", "-f"

say "- Copy stylesheets..."
remove_file 'app/assets/stylesheets/foundation_and_overrides.scss'
%w(application.scss devise.scss foundation_and_overrides.scss inline_forms.scss).each do |stylesheet|
  copy_file File.join(GENERATOR_PATH, 'lib/generators/assets/stylesheets' , stylesheet), File.join('app/assets/stylesheets' , stylesheet)
end

say "- Copy javascripts..."
%w(application.js inline_forms.js).each do |javascript|
  copy_file File.join(GENERATOR_PATH, 'lib/generators/assets/javascripts' , javascript), File.join('app/assets/javascripts' , javascript)
end

say "- Install ckeditor..."
generate "ckeditor:install --orm=active_record --backend=carrierwave"

say "- Mount Ckeditor::Engine to routes..."
route "mount Ckeditor::Engine => '/ckeditor'"

say "- Add ckeditor autoload_paths to application.rb..."
application "config.autoload_paths += %W(\#{config.root}/app/models/ckeditor)"

say "- Create ckeditor config.js"
copy_file File.join(GENERATOR_PATH, 'lib/generators/assets/javascripts/ckeditor/config.js'), "app/assets/javascripts/ckeditor/config.js"

say "- Paper_trail install..."
generate "paper_trail:install" # TODO One day, we need some management tools so we can actually SEE the versions, restore them etc.


# Create Translations
say "- Generate models and tables and views for translations..." # TODO Translations need to be done in inline_forms, and then generate a yml file, perhaps
generate "inline_forms", "InlineFormsLocale name:string inline_forms_translations:belongs_to _enabled:yes _presentation:\#{name}"
generate "inline_forms", "InlineFormsKey name:string inline_forms_translations:has_many inline_forms_translations:associated _enabled:yes _presentation:\#{name}"
generate "inline_forms", "InlineFormsTranslation inline_forms_key:belongs_to inline_forms_locale:dropdown value:text interpolations:text is_proc:boolean _presentation:\#{value}"
# TODO: fix text_area into text_area_without_ckeditor
sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "inline_forms_create_view_for_translations.rb", <<-VIEW_MIGRATION.strip_heredoc
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
run "bundle exec rake db:migrate" if ENV['using_sqlite'] == 'true'

say "- Seeding the database (only when using sqlite)"
run "bundle exec rake db:seed" if ENV['using_sqlite'] == 'true'

say "- Recreating ApplicationHelper to set application_name and application_title..."
remove_file "app/helpers/application_helper.rb" # the one that 'rails new' created
create_file "app/helpers/application_helper.rb", <<-END_APPHELPER.strip_heredoc
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
create_file "app/controllers/application_controller.rb", <<-END_APPCONTROLLER.strip_heredoc
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

    ActionView::CompiledTemplates::MODEL_TABS = %w()

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

say "- Creating Ability model so that the superadmin can access all..."
create_file "app/models/ability.rb", <<-END_ABILITY.strip_heredoc
  class Ability
    include CanCan::Ability

    def initialize(user)
      # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities

      user ||= user.new # guest user

      # use this if you get stuck:
      # if user.id == 1 #quick hack
      #   can :access, :all
      if user.role? :superadmin
        can :access, :all
      else
        # put restrictions for other users here
      end
    end
  end
END_ABILITY

say "- Generating test files", :green

create_file "spec/spec_helper.rb", <<-END_TEST_HELPER.strip_heredoc
  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'development' # this need to be changed to test ???
  require File.expand_path("../../config/environment", __FILE__)
  require 'capybara/rspec'
  require 'rspec/rails'
  require 'rspec/autorun'
  require 'carrierwave/test/matchers'


  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

  RSpec.configure do |config|
    config.include FactoryGirl::Syntax::Methods
    # ## Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr

    # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
    config.fixture_path = Rails.root + "/spec/fixtures"

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true

    # If true, the base class of anonymous controllers will be inferred
    # automatically. This will be the default behavior in future versions of
    # rspec-rails.
    config.infer_base_class_for_anonymous_controllers = false

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = "random"
  end
END_TEST_HELPER

say 'copy test image into rspec folder'
copy_file File.join(GENERATOR_PATH,'lib/otherstuff/fixtures/rails.png'), "spec/fixtures/images/rails.png"
say '- Creating factory_girl file'
create_file "spec/factories/inline_forms.rb", <<-END_FACTORY_GIRL.strip_heredoc
  FactoryGirl.define do
    factory :apartment do
      name "Luxe House in Bandabou 147A" #string
      title "A dream house in a dream place" # string
      description "A beatiful House at the edge of the <strong>sea</strong>" #text
    end
    factory :large_text do
      name "Luxe House in Bandabou 147A" #string
      title "A dream house in a dream place" # string
      description "A beatiful House at the edge of the <strong>sea</strong>" #text
    end
  end
END_FACTORY_GIRL
remove_file 'spec/factories/users.rb'
remove_file 'spec/models/user_spec.rb'

# devise mailer stuff
say "- Injecting devise mailer stuff in environments/production.rb..."
# strip_heredoc_with_indent(2) became strip_heredoc(2), but only in rails 4... :-(
insert_into_file "config/environments/production.rb", <<-DEVISE_MAILER_STUFF.strip_heredoc, :before => "end\n"
  # for devise
  config.action_mailer.default_url_options = { protocol: 'https', host: 'YOURHOSTNAME' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'YOURMAILSERVER',
    enable_starttls_auto: true,
    password: 'YOURPASSWORD',
    user_name: 'YOURUSERNAME'
  }

DEVISE_MAILER_STUFF

say "- Injecting devise mailer stuff in environments/development.rb..."
# strip_heredoc_with_indent(2) became strip_heredoc(2), but only in rails 4... :-(
insert_into_file "config/environments/development.rb", <<-DEVISE_MAILER_STUFF.strip_heredoc, :before => "\nend\n"
  # for devise
  config.action_mailer.default_url_options = { protocol: 'http', host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'YOURMAILSERVER',
    enable_starttls_auto: true,
    password: 'YOURPASSWORD',
    user_name: 'YOURUSERNAME'
  }

DEVISE_MAILER_STUFF

# capify
say "- Capify..."
run 'capify .'
remove_file "config/deploy.rb" # remove the file capify created!
copy_file File.join(GENERATOR_PATH,'lib/generators/templates/deploy.rb'), "config/deploy.rb"

# Unicorn
say "- Unicorn Config..."
copy_file File.join(GENERATOR_PATH,'lib/generators/templates/unicorn.rb'), "config/unicorn.rb"


# Git
say "- Initializing git..."
run 'git init'

insert_into_file ".gitignore", <<-GITIGNORE.strip_heredoc, :after => "/tmp\n"
  # netbeans
  nbproject
  # remotipart uploads
  public/uploads
GITIGNORE

run 'git add .'
run 'git commit -a -m " * Initial"'

# example
if ENV['install_example'] == 'true'
  say "\nInstalling example application..."
  run 'bundle exec rails g inline_forms Photo name:string caption:string image:image_field description:ckeditor apartment:belongs_to _presentation:\'#{name}\'' # FIXME temporary changed because ckeditor is playing dirty
  run 'bundle exec rails generate uploader Image'
  run 'bundle exec rails g inline_forms Apartment name:string title:string description:ckeditor photos:has_many photos:associated _enabled:yes _presentation:\'#{name}\'' # FIXME temporary changed because ckeditor is playing dirty
  run 'bundle exec rake db:migrate'
  say '-Adding example test'
  create_file "spec/models/#{app_name}_example.rb", <<-END_EXAMPLE_TEST.strip_heredoc
    require "spec_helper"
    describe Apartment do
      it "insert an appartment and retrieve it" do
        appartment_data = create(:apartment)
        first =  Apartment.first.id
        expect(Apartment.first.id).to eq(first)
      end
    end
  END_EXAMPLE_TEST

  run "rspec" if ENV['runtest']

  # done!
  say "\nDone! Now point your browser to http://localhost:3000/apartments !", :yellow
  say "\nPress ctlr-C to quit...", :yellow
  run 'bundle exec rails s'
else
  # run tests
  run "rspec" if ENV['runtest']
  # done!
  say "\nDone! Now make your tables with 'bundle exec rails g inline_forms ...", :yellow
end

#say "- Don't forget: edit .rvmrc, config/{routes.rb, deploy.rb}, .git/config, delete public/index.html\n"
