require "shellwords"

INSTALLER_ROOT = File.expand_path(ENV.fetch("INLINE_FORMS_INSTALLER_ROOT", File.expand_path("..", __dir__)))
INLINE_FORMS_ROOT = File.expand_path(ENV.fetch("INLINE_FORMS_ROOT", INSTALLER_ROOT))
require File.join(INSTALLER_ROOT, "lib", "inline_forms_installer", "create_log")

def use_app_rvm_gemset!
  return if ENV["skiprvm"] == "true"
  return unless (gemset = ENV["inline_forms_rvm_gemset"]).to_s != ""

  begin
    require "rvm"
  rescue LoadError
    say "rvm gem not available; skipping gemset switch", :yellow
    return
  end
  return unless RVM.current

  say "Working directory is #{Dir.pwd}", :green
  RVM.use_from_path! "."
  say "Installing using gemset: #{RVM.current.environment_name}", :green
end

def bundle_install!
  say "- Running bundle install..."
  unless system("bundle", "install")
    abort "ERROR: bundle install failed in #{Dir.pwd}. From the app directory run: rvm use . && bundle install"
  end
  unless system("bundle", "check")
    abort "ERROR: bundle check failed (gems missing). From the app directory run: rvm use . && bundle install"
  end
end

# Pin Ruby for the generated app (after `rails new`; do not write these files in
# Creator before `rails new` — Rails also emits `.ruby-version` and prompts).
create_file ".ruby-version", "#{ENV.fetch('ruby_version', 'ruby-4.0.4')}\n"
if (gemset = ENV["inline_forms_rvm_gemset"]).to_s != ""
  create_file ".ruby-gemset", "#{gemset}\n"
end
use_app_rvm_gemset!

# Rails 7 dropped --skip-gemfile, so `rails new` always writes its own Gemfile.
# Remove it so our `create_file` below does not prompt for overwrite.
remove_file 'Gemfile' if File.exist?('Gemfile')
create_file 'Gemfile', "# created by inline_forms_installer #{ENV['inline_forms_installer_version']} on #{Date.today}\n"

# `rails new` is invoked with whatever the system `rails` binary points at
# (often Rails 8.x), so the generated `config/application.rb` may carry
# `load_defaults 8.0` and other 8.x-only settings. The Gemfile below pins
# `rails ~> 7.2.3`; normalize application.rb so the first `bundle exec rails`
# boot matches that pin.
if File.exist?('config/application.rb')
  gsub_file 'config/application.rb',
            /config\.load_defaults\s+\d+\.\d+/,
            'config.load_defaults 7.2'
end

add_source 'https://rubygems.org'

gem 'cancancan'
gem 'carrierwave', '~> 3.1'
gem 'devise', '~> 5.0'
gem 'devise-i18n', '~> 1.16'
gem 'autoprefixer-rails'
# foundation-rails 6.7+ uses Dart Sass (`sass:math`); sass-rails/sassc removed.
# Visually tuned against foundation-rails ~> 6.6.2; current pin ~> 6.9 (6.9.0.x).
gem 'foundation-rails', '~> 6.9'
# Pin inline_forms and validation_hints on the 7.x line; Bundler resolves the
# highest 7.x that satisfies all deps. Set INLINE_FORMS_GEMFILE_PATH for
# maintainer local-path overrides only.
if ENV["INLINE_FORMS_GEMFILE_PATH"] && File.directory?(ENV["INLINE_FORMS_GEMFILE_PATH"])
  gem "inline_forms", path: ENV["INLINE_FORMS_GEMFILE_PATH"]
else
  gem "inline_forms", "~> 7"
end
gem 'jquery-rails'
gem 'jquery-timepicker-rails'
# jQuery UI JavaScript (`//= require jquery.ui.all` in inline_forms.js). SCSS + PNGs
# are vendored in the inline_forms engine (Dart Sass cannot evaluate sass-rails
# `image-path()`). Pin matches former jquery-ui-sass-rails 4.0.3.x stack.
gem 'jquery-ui-rails', '4.0.3'
# Foundation Icons SCSS + fonts are vendored in the inline_forms engine (Dart Sass;
# foundation-icons-sass-rails depended on sass-rails).
gem 'mini_magick'
gem 'mysql2'
gem 'paper_trail', '~> 16.0'
gem 'rails-i18n', '~> 7.0'
gem 'rails-jquery-autocomplete'
gem 'rails', '~> 7.2.3'
gem 'rake'
gem 'rvm'
gem 'dartsass-rails'
# Rails 7 no longer adds sprockets-rails to the default Gemfile; declare it
# explicitly because the gem's own assets (foundation, jquery, etc.) live in
# app/assets and rely on the Sprockets pipeline.
gem 'sprockets-rails'
# Rails 7 default JavaScript tooling: importmap-rails replaces Webpacker.
gem 'importmap-rails'
# Hotwire/Turbo. Loaded from layouts as `<script type="module">`; inline flows
# use `<turbo-frame>` + HTML responses (see docs/ujs-to-turbo.md). Registers the
# `turbo_stream` MIME type for optional stream responses.
gem 'turbo-rails'
gem 'tabs_on_rails', '~> 3.0'
gem 'unicorn'
gem 'validation_hints', '~> 7'
gem 'will_paginate'

gem_group :test do
  # Rails 7 still expects Minitest 5; 6.x breaks the railties test runner.
  gem 'minitest', '~> 5.25'
end

gem_group :development do
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano', require: false
  gem 'capistrano3-unicorn'
  gem 'listen'
  gem 'foreman'
  gem 'puma', '>= 5.0'
  gem 'rvm-capistrano', :require => false
  gem 'rvm1-capistrano3', require: false
  gem 'seed_dump', '~> 0.5.3'
  # Rails 6.1 ActiveRecord's sqlite3 adapter requires sqlite3 ~> 1.4; 2.x activates first and breaks.
  gem 'sqlite3', '~> 1.4'
  gem 'thin'
  gem 'yaml_db'
end

gem_group :production do
  gem 'mini_racer'
  gem 'uglifier'
end

say "- Running bundle..."
run "gem install bundler --no-document"
if (vh_root = ENV["VALIDATION_HINTS_ROOT"]) && File.directory?(vh_root)
  vh_gem = Dir[File.join(vh_root, "validation_hints-*.gem")].sort.last
  if vh_gem && File.file?(vh_gem)
    say "- Installing #{File.basename(vh_gem)} from VALIDATION_HINTS_ROOT..."
    run "gem install #{vh_gem} --no-document"
  end
end
bundle_install!

say "- Dart Sass: inline_forms stylesheet entrypoints + initializer..."
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/inline_forms_dartsass_builds.rb"),
          "config/initializers/inline_forms_dartsass_builds.rb"
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/inline_forms_main.scss"),
          "app/assets/stylesheets/inline_forms_install/inline_forms_main.scss"
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/devise_main.scss"),
          "app/assets/stylesheets/inline_forms_install/devise_main.scss"

say "- Dart Sass: rails dartsass:install (builds/, manifest, Procfile.dev)..."
run "bundle exec rails dartsass:install"

say "- Dart Sass: drop default application.css (manifest links builds/*.css only)..."
remove_file "app/assets/stylesheets/application.css"

insert_into_file "test/test_helper.rb", <<~'DARTSASS_TEST', after: %(require "rails/test_help"\n)

  # Dart Sass writes CSS to app/assets/builds; Sprockets does not compile .scss.
  Rails.application.load_tasks
  Rake::Task["dartsass:build"].invoke
DARTSASS_TEST

say "- Database setup: creating config/database.yml with development database #{ENV['database']}"
remove_file "config/database.yml" # the one that 'rails new' created
if ENV['using_sqlite'] == 'true'
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  development:
    adapter: sqlite3
    database: db/development.sqlite3
    pool: 5
    timeout: 5000

  test:
    adapter: sqlite3
    database: db/test.sqlite3
    pool: 5
    timeout: 5000

  END_DATABASEYML
else
  create_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  development:
    adapter: mysql2
    database: <%= Rails.application.credentials[:db_name] %>
    username: <%= Rails.application.credentials[:db_username] %>
    password: <%= Rails.application.credentials[:db_password] %>
  END_DATABASEYML

say "- Setting development database in credentials"
create_file "temp_development_database_credentials", <<-END_DEV_DB_CRED.strip_heredoc

  # development database
  db_name: #{app_name.downcase}_dev
  db_username: #{app_name.downcase}_dev_user
  db_password: #{app_name.downcase}_dev_password

END_DEV_DB_CRED

run "EDITOR='cat temp_development_database_credentials >> ' rails credentials:edit"

remove_file 'temp_development_database_credentials'

say "\n *** Please make sure to create a mysql development database with the following credentials:
    db_name: #{app_name.downcase}_dev
    db_username: #{app_name.downcase}_dev_user
    db_password: #{app_name.downcase}_dev_password

    or use 'rails credentials:edit' to change these values.\n\n", :red

end
append_file "config/database.yml", <<-END_DATABASEYML.strip_heredoc
  production:
    adapter: mysql2
    database: <%= Rails.application.credentials[:db_name] %>
    username: <%= Rails.application.credentials[:db_username] %>
    password: <%= Rails.application.credentials[:db_password] %>
END_DATABASEYML

say "Setting production database in credentials"
create_file "temp_production_database_credentials", <<-END_PROD_DB_CRED.strip_heredoc

  # production database
  db_name: #{app_name.downcase}_prod
  db_username: #{app_name.downcase}_prod_user
  db_password:

END_PROD_DB_CRED

run "EDITOR='cat temp_production_database_credentials >> ' rails credentials:edit --environment production"

remove_file 'temp_production_database_credentials'

say "\n *** Please make sure to create a mysql production database and use 'rails credentials:edit' to set the password.\n\n", :red

say "- Devise install..."
run "bundle exec rails g devise:install"

say "- Create Devise route and add path_prefix..."

route <<-ROUTE.strip_heredoc
devise_for :users, :path_prefix => 'auth'
  resources :users do
    post 'revert', :on => :member
    get 'list_versions', :on => :member
end
ROUTE

say "- Create devise migration file"

sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "devise_create_users.rb", <<-DEVISE_MIGRATION.strip_heredoc
class DeviseCreateUsers < ActiveRecord::Migration[7.2]

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
  class User < ApplicationRecord

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
    #attr_accessible :email, :password, :locale, :remember_me

    belongs_to :locale
    has_and_belongs_to_many :roles

    # validations
    validates :name, :presence => true

    default_scope {order :name}

    # pagination
    attr_reader :per_page
    @per_page = 7

    has_paper_trail on: [:create, :update, :destroy]

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

# Create Locales
say "- Create locales"
generate "inline_forms", "Locale name:string title:string users:has_many _enabled:yes _presentation:\#{title}"
append_to_file "db/seeds.rb", "Locale.create({ id: 1, name: 'en', title: 'English' })\n"

# Create Roles
say "- Create roles"
generate "inline_forms", "Role name:string description:text users:has_and_belongs_to_many _enabled:yes _presentation:\#{name}"
append_to_file "db/seeds.rb", "Role.create({ id: 1, name: 'superadmin', description: 'Super Admin can access all.' })\n"

# Create Admin User

say "- Adding admin user with email: #{ENV['email']}, password: #{ENV['password']} to seeds.rb"
append_to_file "db/seeds.rb", "User.create({ id: 1, email: '#{ENV['email']}', locale_id: 1, name: 'Admin', password: '#{ENV['password']}', password_confirmation: '#{ENV['password']}' })\n"


sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "inline_forms_create_join_table_user_role.rb", <<-ROLES_MIGRATION.strip_heredoc
  class InlineFormsCreateJoinTableUserRole < ActiveRecord::Migration[7.2]
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


say "- Installaing ZURB Foundation..."
#generate "foundation:install", "-f"

say "- Copy inline_forms_devise file for custom styles..."
copy_file File.join(INLINE_FORMS_ROOT, 'lib/generators/assets/stylesheets/inline_forms_devise.css'), 'app/assets/stylesheets/inline_forms_devise.css'

say "- Sprockets: link inline_forms_devise.css (logical path; dartsass:install drops link_directory ../stylesheets)..."
append_to_file "app/assets/config/manifest.js", "//= link inline_forms_devise.css\n"

say "- Add human_attribute_name in app/models/application_record.rb"
remove_file 'app/models/application_record.rb' # the one that 'rails new' created
copy_file File.join(INLINE_FORMS_ROOT, 'lib/generators/templates/application_record.rb'), "app/models/application_record.rb"

say "- Install ActionText..."
run "bundle exec rails active_storage:install"
run "bundle exec rails action_text:install:migrations"
bundle_install!

say "- Paper_trail install..."
# Upstream paper_trail (>= 13) detects MySQL via the live ActiveRecord connection,
# so the migration's InnoDB options are added only when the dev DB is mysql.
# For mysql installs the user has been instructed above to create the development
# database before continuing; for sqlite the file is created on first connection.
generate "paper_trail:install --with-changes"
# paper_trail emits two migrations in one second; the next generator would reuse that timestamp.
sleep 1

say "- Track ActionText (rich_text) edits with PaperTrail..."
# `has_rich_text :foo` stores the body in the separate `action_text_rich_texts`
# table, not on the parent model, so `has_paper_trail` on the parent never
# sees rich_text edits. The standard fix (recommended by paper_trail's
# maintainer in https://stackoverflow.com/q/55544935) is to declare
# `has_paper_trail` directly on `ActionText::RichText`. We surface those
# versions in the parent's versions panel from `inline_forms_versions_for`.
#
# Note: PaperTrail >= 16 raises if `has_paper_trail` is called twice on the
# same model, so this initializer must be the only place it's added to
# `ActionText::RichText` in the generated app.
create_file 'config/initializers/rich_text_paper_trail.rb', <<-PT_RICH_TEXT.strip_heredoc
  # Generated by inline_forms.
  # Mirror the per-model opt-out from `:touch` (see app/models/*.rb): nothing
  # touches ActionText::RichText today, but if a future association adds
  # `touch: true` pointing at it, the parent versions panel must not surface
  # touch-only "empty" rich-text rows whose Restore link reifies a no-op.
  ActiveSupport.on_load(:action_text_rich_text) do
    has_paper_trail on: [:create, :update, :destroy]
  end
PT_RICH_TEXT

say "- Configure ActiveRecord YAML permitted classes for PaperTrail changesets..."
# PaperTrail's YAML serializer (>= 13) uses `YAML.safe_load` and reads its
# allow-list from `ActiveRecord.yaml_column_permitted_classes`. Rails 7's
# default is `[Symbol]`, so any update that touches `updated_at`
# (an `ActiveSupport::TimeWithZone`) raises `Psych::DisallowedClass` inside
# `version.changeset`; PaperTrail rescues that and returns `{}`, which is why
# the inline_forms versions list rendered every changeset as `empty`. Permit
# the classes PT actually emits so `version.changeset` round-trips.
create_file 'config/initializers/paper_trail_yaml_safe_load.rb', <<-PT_YAML.strip_heredoc
  # Generated by inline_forms.
  # See https://github.com/paper-trail-gem/paper_trail and
  # ActiveRecord::Coders::YAMLColumn safe-loading rules.
  Rails.application.config.active_record.yaml_column_permitted_classes ||= []
  Rails.application.config.active_record.yaml_column_permitted_classes |= [
    Symbol,
    Date,
    Time,
    BigDecimal,
    ActiveSupport::TimeWithZone,
    ActiveSupport::TimeZone,
    ActiveSupport::HashWithIndifferentAccess
  ]
  ActiveRecord.yaml_column_permitted_classes |= Rails.application.config.active_record.yaml_column_permitted_classes
PT_YAML

say "- Creating application title via locales..."
create_file "config/locales/inline_forms_local.en.yml", <<-END_LOCALE.strip_heredoc
  en:
    inline_forms:
      general:
        application_title: #{app_name}
      devise:
        title_for_devise: #{app_name}
        welcome: Welcome to #{app_name}!
END_LOCALE

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

say "- Creating inline_forms initializer"
create_file "config/initializers/inline_forms.rb", <<-END_INITIALIZER.strip_heredoc
  Rails.application.reloader.to_prepare do
    MODEL_TABS = %w()
  end
END_INITIALIZER

say "- Recreating ApplicationController to add devise, cancan, I18n stuff..."
remove_file "app/controllers/application_controller.rb" # the one that 'rails new' created
create_file "app/controllers/application_controller.rb", <<-END_APPCONTROLLER.strip_heredoc
  class ApplicationController < InlineFormsApplicationController
    protect_from_forgery

    # add whodunnit
    before_action :set_paper_trail_whodunnit

    # Comment next lines if you don't want Devise authentication
    before_action :authenticate_user!
    check_authorization unless: :devise_controller?

    rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.json { head :forbidden, content_type: 'text/html' }
        format.html { redirect_to main_app.root_url, notice: exception.message }
        format.js   { head :forbidden, content_type: 'text/html' }
      end
    end
    # Comment previous lines if you don't want Devise authentication

    # Uncomment next line if you want I18n (based on subdomain)
    # before_action :set_locale

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
      # See the wiki for details: https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities

      user ||= User.new # guest user

      # use this if you get stuck:
      # if user.id == 1 #quick hack
      #   can :manage, :all
      if user.role? :superadmin
        can :manage, :all
      else
        # put restrictions for other users here
      end
    end
  end
END_ABILITY

# devise mailer stuff
say "- Injecting devise mailer stuff in environments/production.rb..."
# strip_heredoc_with_indent(2) became strip_heredoc(2), but only in rails 4... :-(
insert_into_file "config/environments/production.rb", <<-DEVISE_MAILER_PROD_STUFF.strip_heredoc, :before => "end\n"

  # for devise
  config.action_mailer.default_url_options = { protocol: 'https', host: Rails.application.credentials[:smtp_app_host] }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: Rails.application.credentials[:smtp_host],
    enable_starttls_auto: true,
    password: Rails.application.credentials[:smtp_password] ,
    user_name: Rails.application.credentials[:smtp_username]
  }

DEVISE_MAILER_PROD_STUFF

say "Setting production smtp settings in credentials"
create_file "temp_production_smtp_credentials", <<-END_PROD_SMTP_CRED.strip_heredoc

  # devise mailer stuff for production:
  smtp_app_host: APP_HOST
  smtp_host: SMTP_HOST
  smtp_username: USERNAME
  smtp_password: PASSWORD

END_PROD_SMTP_CRED

run "EDITOR='cat temp_production_smtp_credentials >> ' rails credentials:edit --environment production"

remove_file 'temp_production_smtp_credentials'

say "- Injecting devise mailer stuff in environments/development.rb..."
# strip_heredoc_with_indent(2) became strip_heredoc(2), but only in rails 4... :-(
insert_into_file "config/environments/development.rb", <<-DEVISE_MAILER_DEV_STUFF.strip_heredoc, :before => "\nend\n"
  # for devise
  config.action_mailer.default_url_options = { protocol: 'http', host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: Rails.application.credentials[:smtp_host],
    enable_starttls_auto: true,
    password: Rails.application.credentials[:smtp_password] ,
    user_name: Rails.application.credentials[:smtp_username]
  }

DEVISE_MAILER_DEV_STUFF

say "Setting development smtp settings in credentials"
create_file "temp_development_smtp_credentials", <<-END_DEV_SMTP_CRED.strip_heredoc

  # devise mailers stuff for development:
  smtp_app_host: APP_HOST
  smtp_host: SMTP_HOST
  smtp_username: USERNAME
  smtp_password: PASSWORD

END_DEV_SMTP_CRED

run "EDITOR='cat temp_development_smtp_credentials >> ' rails credentials:edit"

remove_file 'temp_development_smtp_credentials'



# capify
say "- Capify..."
run 'bundle exec cap install'
remove_file "config/deploy.rb" # remove the file capify created!
copy_file File.join(INSTALLER_ROOT,'lib/installer_templates/capistrano/deploy.rb'), "config/deploy.rb"
remove_file "config/deploy/production.rb" # remove the production file capify created!
copy_file File.join(INSTALLER_ROOT,'lib/installer_templates/capistrano/production.rb'), "config/deploy/production.rb"
remove_file "Capfile" # remove the Capfile file capify created!
copy_file File.join(INSTALLER_ROOT,'lib/installer_templates/capistrano/Capfile'), "Capfile"

# Unicorn
say "- Unicorn Config..."
copy_file File.join(INSTALLER_ROOT,'lib/installer_templates/unicorn/production.rb'), "config/unicorn/production.rb"

# Git
say "- adding and committing to git..."

git add: "."
git commit: " -a -m 'Initial Commit'"

# example
if ENV['install_example'] == 'true'
  say "\nInstalling example application..."
  run 'bundle exec rails g inline_forms Photo name:string caption:string image:image_field description:rich_text apartment:belongs_to _presentation:\'#{name}\''
  run 'bundle exec rails generate uploader Image'
  run 'bundle exec rails g inline_forms Apartment name:string title:string opening_date:date description:rich_text photos:has_many photos:associated _enabled:yes _presentation:\'#{name}\''

  say "- Apartment name is required..."
  inject_into_file "app/models/apartment.rb",
                   "\n  validates :name, presence: true\n",
                   after: "  has_paper_trail on: [:create, :update, :destroy]\n"

  # CarrierWave + PaperTrail history.
  # PaperTrail snapshots the column scalar (the stored filename) on update,
  # but CarrierWave's default `remove_previously_stored_files_after_update`
  # deletes the old file on disk and re-uses the same filename, so a
  # PaperTrail revert restores a filename whose bytes are gone.
  # We keep every uploaded file on disk and namespace filenames with a
  # per-upload token so successive uploads do not collide. See
  # https://stackoverflow.com/questions/9423279/papertrail-and-carrierwave
  # (Answers 2, 4 and 5).
  say "- Configuring CarrierWave to keep previously stored files (PaperTrail history)..."
  create_file "config/initializers/carrierwave.rb", <<-CWINIT.strip_heredoc
    # Keep previously stored files on disk so PaperTrail-driven restore
    # actually returns the previous image bytes. See
    # https://stackoverflow.com/questions/9423279/papertrail-and-carrierwave
    # The per-uploader overrides in app/uploaders/image_uploader.rb
    # complement this by giving every upload a unique on-disk filename
    # and by no-op'ing `remove!` so destroyed records keep their files.
    CarrierWave.configure do |config|
      config.remove_previously_stored_files_after_update = false
    end
  CWINIT

  inject_into_file "app/uploaders/image_uploader.rb",
                   after: "class ImageUploader < CarrierWave::Uploader::Base\n" do
    <<-RUBY.strip_heredoc.gsub(/^/, "  ")
      # PaperTrail history support. CarrierWave's default behaviour wipes the
      # previous file on update and reuses the same filename; PaperTrail only
      # stores the column scalar, so a plain `version.reify; save!` restores a
      # filename whose bytes are gone. The knobs below preserve every byte:
      #
      #   * `remove_previously_stored_files_after_update = false` is set
      #     globally in config/initializers/carrierwave.rb (covers
      #     `multi_image_field` uploaders too).
      #   * `remove!` is a no-op so hard-destroyed records keep their files
      #     and revert-after-destroy still finds the bytes on disk.
      #   * `filename` is prefixed with a per-upload UUID so successive
      #     uploads never collide on disk.
      #
      # Trade-off: files accumulate on disk; sweeping is out of scope.
      # Source: https://stackoverflow.com/questions/9423279/papertrail-and-carrierwave
      def remove!
        # no-op: keep the file so PaperTrail revert can restore it.
      end

      def filename
        # CarrierWave 3.x calls `filename` again after storing to record the
        # persisted name; at that point `original_filename` may be nil and we
        # must still return the memoized name (see
        # https://github.com/carrierwaveuploader/carrierwave/issues/2708).
        @name ||= "\#{secure_token}-\#{original_filename}" if original_filename
        @name
      end

      private

      def secure_token
        var = :"@\#{mounted_as}_secure_token"
        model.instance_variable_get(var) || model.instance_variable_set(var, SecureRandom.uuid)
      end
    RUBY
  end

  say "- Lower Photo.per_page so the seeded gallery paginates..."
  # The model template (lib/generators/templates/model.erb) emits
  #   attr_reader :per_page
  #   @per_page = 7
  # which is a long-standing typo: `attr_reader :per_page` defines an
  # *instance* method, then `@per_page = 7` (executed in the class body)
  # actively *clobbers* the class-level per_page that will_paginate
  # exposes via `class_attribute :per_page` (its singleton-ivar storage
  # also lives on `@per_page`). Net effect: nothing reads 7 anywhere,
  # and the class-level per_page silently reverts to will_paginate's
  # 30-default. Replace the pair on Photo with a real `self.per_page = 5`
  # so the seeded gallery (12 photos) actually paginates 5/5/2.
  gsub_file "app/models/photo.rb",
            /^\s*attr_reader\s+:per_page\s*\n\s*@per_page\s*=\s*\d+\s*\n/,
            "  self.per_page = 5\n"

  run 'bundle exec rake db:migrate'

  # Seed the photos gallery from a local `pics/` folder. The folder is
  # *gitignored* in the gem source (so the built .gem stays small and
  # the gallery images are not committed) which means INSTALLER_ROOT/pics
  # exists only when the installer is run from the source repo, not when
  # it is run from an installed gem on the developer's box. We therefore
  # check, in order:
  #   1. ENV['INLINE_FORMS_SEED_PICS']  -- explicit override path
  #   2. INSTALLER_ROOT/pics            -- monorepo / installer checkout
  #   3. /home/code/inline_forms/pics   -- local dev convention
  # and copy whichever is found into the generated app's db/seed_images/.
  # The migration generated below is what reads from db/seed_images at
  # `db:migrate` / `db:test:prepare` time, so this copy is only ever a
  # one-shot at app generation.
  pics_candidates = [
    ENV["INLINE_FORMS_SEED_PICS"],
    File.join(INSTALLER_ROOT, "pics"),
    "/home/code/inline_forms/pics",
  ].compact
  pics_src = pics_candidates.find { |p| Dir.exist?(p) }
  if pics_src
    seed_pics = Dir.glob(File.join(pics_src, "*.{jpg,jpeg,JPG,JPEG,png,PNG,gif,GIF}")).sort
    if seed_pics.any?
      say "- Copying #{seed_pics.size} sample photo(s) into db/seed_images/..."
      empty_directory "db/seed_images"
      seed_pics.each do |abs|
        copy_file abs, File.join("db/seed_images", File.basename(abs))
      end

      # The actual seed migration for 3 apartments + 3 owners + photos
      # is generated AFTER the Owner setup below (so it can reference
      # owners + apartments.owner_id). We just copy the seed pics here.
    end
  end

  remove_file 'public/index.html'

  say "- Apartment name list demo (field-level inline edit without _show)..."
  inject_into_file "app/controllers/apartments_controller.rb",
                   "\n  skip_load_and_authorize_resource only: :name_list\n\n  def name_list\n    authorize! :read, Apartment\n    @apartments = Apartment.accessible_by(current_ability).order(:id).limit(10)\n  end\n",
                   after: "set_tab :apartment\n"

  # Owner -- demonstrates per-resource sub-tabs on /owners/:id.
  # Owner has many Apartments; an Apartment belongs to one Owner. The
  # Owner detail panel renders two Turbo tabs (`naw`, `apartments`) via
  # InlineForms::TurboTabsBuilder; both tabs surface :name, hence the
  # shared first field. See OwnersController override below.
  say "- Generating Owner model (has_many apartments)..."
  sleep 1
  run %q{bundle exec rails g inline_forms Owner name:string birthdate:date address:string city:string country:string apartments:has_many apartments:associated _enabled:yes _presentation:'#{name}'}

  say "- Owner name is required..."
  inject_into_file "app/models/owner.rb",
                   "\n  validates :name, presence: true\n",
                   after: "  has_paper_trail on: [:create, :update, :destroy]\n"

  say "- Adding owner_id to apartments + belongs_to :owner..."
  sleep 1
  add_owner_ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{add_owner_ts}_add_owner_to_apartments.rb", <<-ADD_OWNER.strip_heredoc
    class AddOwnerToApartments < ActiveRecord::Migration[7.2]
      def change
        add_reference :apartments, :owner, null: true, foreign_key: true
      end
    end
  ADD_OWNER

  inject_into_file "app/models/apartment.rb",
                   "  belongs_to :owner, optional: true\n",
                   after: "  has_paper_trail on: [:create, :update, :destroy]\n"

  # Insert the :owner dropdown row at the top of Apartment's attribute list
  # so it appears above :name in the inline panel.
  gsub_file "app/models/apartment.rb",
            /@inline_forms_attribute_list \|\|= \[\n/,
            "@inline_forms_attribute_list ||= [\n     [ :owner , \"owner\", :dropdown ], \n"

  # Owner -> apartments: render as a check_list of EXISTING apartments
  # (not the default :associated panel that only lets you create new
  # rows nested under the owner). Standard Rails has_many gives us the
  # `apartment_ids=` setter that CheckListHelper uses, so we just swap
  # the form element kind in the generated attribute list.
  gsub_file "app/models/owner.rb",
            /\[ :apartments , "apartments", :associated \]/,
            '[ :apartments , "apartments", :check_list ]'

  say "- Replacing OwnersController with tabbed-show variant (/owners/:id)..."
  remove_file "app/controllers/owners_controller.rb"
  create_file "app/controllers/owners_controller.rb", <<-OWNERS_CTRL.strip_heredoc
    class OwnersController < InlineFormsController
      set_tab :owner

      # Per-owner sub-tabs. `name` appears on both tabs by design (the user
      # asked for `name + apartments` on one tab and `naw` -- name,
      # birthdate, address, city, country -- on the other).
      OWNER_TABS = %w[naw apartments].freeze
      OWNER_TAB_FIELDS = {
        "naw"        => %i[name birthdate address city country],
        "apartments" => %i[name apartments],
      }.freeze

      def show
        # Field-level inline edit / cancel / explicit close requests
        # still go through the stock `_show` / field flows.
        return super if params[:form_element] || params[:attribute] || params[:close]

        @object = Owner.find(params[:id])
        @update_span = params[:update].presence || "owner_\#{@object.id}"

        tab = OWNER_TABS.include?(params[:tab].to_s) ? params[:tab].to_s : "naw"
        set_tab tab.to_sym
        @inline_forms_owner_tabs    = OWNER_TABS
        @inline_forms_attribute_list = owner_attributes_for(tab)
        @inline_forms_turbo_row     = true

        render "owners/show_with_tabs",
               layout: turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
      end

      private

      def owner_attributes_for(tab)
        full = @object.inline_forms_attribute_list
        OWNER_TAB_FIELDS.fetch(tab).map do |attr|
          full.find { |a, _, _| a == attr } ||
            raise("OwnersController: attribute \#{attr.inspect} missing from Owner#inline_forms_attribute_list")
        end
      end
    end
  OWNERS_CTRL

  # Seed the example app with 3 apartments + 3 owners and assign photos
  # from db/seed_images. Runs as a regular migration so `bundle exec rake
  # db:migrate` (and `rails db:setup` on a fresh checkout) populates the
  # demo gallery in one shot. Idempotent via find_or_create_by!.
  say "- Generating seed migration (3 apartments + 3 owners + photo gallery)..."
  sleep 1
  seed_ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{seed_ts}_seed_example_apartments_and_owners.rb", <<-SEED_MIGRATION.strip_heredoc
    class SeedExampleApartmentsAndOwners < ActiveRecord::Migration[7.2]
      # ---------------------------------------------------------------
      # Apartment seed gallery
      # ---------------------------------------------------------------
      # Three apartments named "Apt 1", "Apt 2", "Apt 3". Each apartment
      # gets the photos under db/seed_images/ that start with apt<N>_,
      # falling back to a slice of the directory when no per-apartment
      # files match. The default seed_images shipped with the gem are
      # CC0 placeholders generated by the installer (solid pastel +
      # apartment label), so users can fork and replace freely.
      APARTMENTS = [
        { name: "Apt 1", title: "Casa Aurora",   opening_date: Date.new(2026, 1, 10) },
        { name: "Apt 2", title: "Villa Marina",  opening_date: Date.new(2026, 2, 14) },
        { name: "Apt 3", title: "Loft del Sol",  opening_date: Date.new(2026, 3, 21) },
      ].freeze

      # ---------------------------------------------------------------
      # Owners
      # ---------------------------------------------------------------
      # Maria owns Apt 1 + Apt 2 (the "many" case), Jean-Pierre owns
      # exactly one (Apt 3), and Akira owns zero apartments so the
      # check_list edit panel on /owners/:id can be exercised against
      # an empty association too.
      OWNERS = [
        { name: "Maria Martinez",
          birthdate: Date.new(1984, 7, 12),
          address: "Calle del Sol 42",
          city: "Willemstad",
          country: "Curacao",
          apartments: ["Apt 1", "Apt 2"] },
        { name: "Jean-Pierre Dupont",
          birthdate: Date.new(1972, 3, 4),
          address: "Rue des Lilas 7",
          city: "Lyon",
          country: "France",
          apartments: ["Apt 3"] },
        { name: "Akira Tanaka",
          birthdate: Date.new(1990, 11, 23),
          address: "1-2-3 Sakura",
          city: "Kyoto",
          country: "Japan",
          apartments: [] },
      ].freeze

      def up
        seed_dir = Rails.root.join("db", "seed_images")
        all_pics = seed_dir.directory? ?
          Dir.glob(seed_dir.join("*.{png,jpg,jpeg,gif}"), File::FNM_CASEFOLD).sort :
          []

        apt_records = {}
        APARTMENTS.each_with_index do |spec, idx|
          apt = Apartment.find_or_create_by!(name: spec[:name]) do |a|
            a.title        = spec[:title]
            a.opening_date = spec[:opening_date]
          end

          prefix = "apt\#{idx + 1}_"
          per_apt = all_pics.select { |abs| File.basename(abs).downcase.start_with?(prefix) }
          per_apt = all_pics.each_slice(3).to_a[idx].to_a if per_apt.empty? && all_pics.any?

          per_apt.each do |abs|
            base = File.basename(abs)
            next if Photo.exists?(name: base, apartment_id: apt.id)
            File.open(abs, "rb") do |io|
              Photo.create!(
                name: base,
                caption: "\#{spec[:title]} -- \#{base}",
                apartment: apt,
                image: io
              )
            end
          end

          apt_records[spec[:name]] = apt
        end

        OWNERS.each do |spec|
          owner = Owner.find_or_create_by!(name: spec[:name]) do |o|
            o.birthdate = spec[:birthdate]
            o.address   = spec[:address]
            o.city      = spec[:city]
            o.country   = spec[:country]
          end

          spec[:apartments].each do |apt_name|
            apt = apt_records[apt_name] or next
            apt.update!(owner: owner) unless apt.owner_id == owner.id
          end
        end
      end

      def down
        OWNERS.each do |spec|
          owner = Owner.find_by(name: spec[:name])
          owner&.destroy
        end
        APARTMENTS.each do |spec|
          apt = Apartment.find_by(name: spec[:name])
          next unless apt
          apt.photos.destroy_all
          apt.destroy
        end
      end
    end
  SEED_MIGRATION

  say "- Running migrations for owner + seed (owners + apartments.owner_id + 3 apts/3 owners)..."
  run "bundle exec rake db:migrate"

  example_views_root = File.join(INSTALLER_ROOT, "lib/installer_templates/example_app_views")
  Dir.glob(File.join(example_views_root, "**", "*")).sort.each do |abs|
    next unless File.file?(abs)
    rel = abs.delete_prefix(example_views_root + File::SEPARATOR).tr("\\", "/")
    create_file File.join("app/views", rel), File.read(abs)
  end

  route 'get "apartments/name_list", to: "apartments#name_list", as: :apartment_name_list'
  route "root :to => 'apartments#index'"

  example_tests_root = File.join(INSTALLER_ROOT, "lib/installer_templates/example_app_tests")
  Dir.glob(File.join(example_tests_root, "**", "*.rb")).sort.each do |abs|
    rel = abs.delete_prefix(example_tests_root + File::SEPARATOR).tr("\\", "/")
    create_file rel, File.read(abs)
  end

  say "- Running example regression tests (bundle exec rails test)..."
  log_path = ENV["INLINE_FORMS_INSTALLER_LOG"].to_s
  test_cmd = if log_path != ""
               "bundle exec rails test 2>&1 | tee -a #{Shellwords.escape(log_path)}"
             else
               "bundle exec rails test 2>&1"
             end
  test_ok = system("bash", "-c", "#{test_cmd}; exit ${PIPESTATUS[0]}")
  abort "ERROR: bundle exec rails test failed during --example install. See #{log_path}" unless test_ok

  say "\nDone! Example app (Photo + Apartment + Owner) is ready.", :yellow
  say "  cd #{File.basename(Dir.pwd)} && rvm use . && bundle exec rails s", :yellow
  say "  http://localhost:3000/apartments — #{ENV["email"]} / #{ENV["password"]}", :yellow
  log_path = ENV["INLINE_FORMS_INSTALLER_LOG_DISPLAY"].to_s
  log_path = ENV["INLINE_FORMS_INSTALLER_LOG"].to_s if log_path.empty?
  if log_path != ""
    say "  Install log: #{log_path}", :yellow
  end
end
# done!
say "\nDone! Now make your tables with 'bundle exec rails g inline_forms ...", :yellow
