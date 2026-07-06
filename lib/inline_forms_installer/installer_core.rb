require "shellwords"

INSTALLER_ROOT = File.expand_path(ENV.fetch("INLINE_FORMS_INSTALLER_ROOT", File.expand_path("..", __dir__)))
INLINE_FORMS_ROOT = File.expand_path(ENV.fetch("INLINE_FORMS_ROOT", INSTALLER_ROOT))
require File.join(INSTALLER_ROOT, "lib", "inline_forms_installer", "create_log")
require File.join(INSTALLER_ROOT, "lib", "inline_forms_installer", "user_model_config")

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

# Pre-install built .gem files into the app RVM gemset so Bundler can resolve
# inline_forms ~> 8 before those releases exist on RubyGems. Set
# INLINE_FORMS_RELEASE_ROOT and/or VALIDATION_HINTS_ROOT (creator sets the latter
# when a sibling validation_hints checkout exists).
def install_prerelease_gems_from_roots!
  roots = []
  %w[INLINE_FORMS_RELEASE_ROOT VALIDATION_HINTS_ROOT].each do |key|
    root = ENV[key].to_s
    roots << File.expand_path(root) if root != "" && File.directory?(root)
  end
  roots.uniq!
  return if roots.empty?

  %w[validation_hints inline_forms inline_forms_installer].each do |name|
    # Pick the *highest version*, not the highest filename. String sort
    # placed `inline_forms-8.1.7.gem` above `inline_forms-8.1.10.gem`
    # because "7" > "1" lexicographically — silently picking up a stale
    # gem build on every release once minor versions cross a digit
    # boundary. Parse the version out of the filename with Gem::Version
    # so the comparison is numeric.
    #
    # Look in both the checkout root (`gem build` output) *and* `pkg/`
    # (`rake build` output from Bundler::GemHelper.install_tasks). 8.1.10
    # only globbed the root, so the moment a maintainer ran `rake build`
    # the freshly-built gem ended up in `pkg/` and was invisible — the
    # installer fell back to whatever stale `<name>-*.gem` was still
    # sitting in the checkout root from an earlier `gem build`. That's
    # the exact shape that bit us between 8.1.6 (default gemset's
    # highest installer) and 8.1.10.
    candidates = roots.flat_map { |root|
      Dir[File.join(root, "#{name}-*.gem"), File.join(root, "pkg", "#{name}-*.gem")]
    }
    gem_file = candidates.max_by do |path|
      ver_str = File.basename(path, ".gem").sub(/\A#{Regexp.escape(name)}-/, "")
      Gem::Version.new(ver_str) rescue Gem::Version.new("0")
    end
    next unless gem_file && File.file?(gem_file)

    say "- Installing #{File.basename(gem_file)} into app gemset..."
    run "gem install #{Shellwords.escape(gem_file)} --no-document"
  end
end

# Pin Ruby for the generated app (after `rails new`; do not write these files in
# Creator before `rails new` — Rails also emits `.ruby-version` and prompts).
# `rails new` writes its own `.ruby-version` (under RVM it picks up the ambient
# `ruby-X.Y.Z` string). We always overwrite it with our bare, version-manager-
# agnostic `X.Y.Z` form; `force: true` avoids Thor's interactive overwrite
# prompt when Rails' value differs (it always does, now that we drop the
# RVM-only `ruby-` prefix).
create_file ".ruby-version", "#{ENV.fetch('ruby_version', '4.0.4')}\n", force: true
if (gemset = ENV["inline_forms_rvm_gemset"]).to_s != ""
  create_file ".ruby-gemset", "#{gemset}\n"
end
use_app_rvm_gemset!

# Rails 7 dropped --skip-gemfile, so `rails new` always writes its own Gemfile.
# Remove it so our `create_file` below does not prompt for overwrite.
remove_file 'Gemfile' if File.exist?('Gemfile')
create_file 'Gemfile', "# created by inline_forms_installer #{ENV['inline_forms_installer_version']} on #{Date.today}\n"

# Creator invokes `rails _8.1.x_ new`, which emits `load_defaults 8.1` and removes
# `new_framework_defaults_8_1.rb`. Normalize anyway when an older generator left another minor.
if File.exist?('config/application.rb')
  gsub_file 'config/application.rb',
            /config\.load_defaults\s+\d+\.\d+/,
            'config.load_defaults 8.1'
end

add_source 'https://rubygems.org'

gem 'cancancan', '~> 3.6'
gem 'carrierwave', '~> 3.1'
gem 'devise', '~> 5.0'
gem 'devise-i18n', '~> 1.16'
gem 'autoprefixer-rails'
# foundation-rails 6.7+ uses Dart Sass (`sass:math`); sass-rails/sassc removed.
# Visually tuned against foundation-rails ~> 6.6.2; current pin ~> 6.9 (6.9.0.x).
gem 'foundation-rails', '~> 6.9'
# Pin inline_forms and validation_hints on the 8.x line; Bundler resolves the
# highest 8.x that satisfies all deps. Set INLINE_FORMS_GEMFILE_PATH for
# maintainer local-path overrides only.
if ENV["INLINE_FORMS_GEMFILE_PATH"] && File.directory?(ENV["INLINE_FORMS_GEMFILE_PATH"])
  gem "inline_forms", path: ENV["INLINE_FORMS_GEMFILE_PATH"]
else
  gem "inline_forms", "~> 8"
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
# money-rails powers the `money_field` Tier 1 helper:
#   * adds the `humanized_money_with_symbol` view helper used by
#     money_field_show
#   * exposes `monetize :foo_cents` so an integer `_cents` column is
#     read/written as a Money instance through `obj.foo`
# Used by FormElementShowcase#amount in the --example app.
gem 'money-rails', '~> 3.0'
gem 'mysql2'
gem 'paper_trail', '~> 17.0'
gem 'rails-i18n', '~> 8.1'
gem 'rails-jquery-autocomplete'
gem 'rails', '~> 8.1'
gem 'rake'
# NOTE: the `rvm` gem is intentionally NOT a runtime dependency of generated
# apps — RVM is optional and nothing in the app needs the RVM Ruby API at
# runtime. (The RVM-based Capistrano deploy helpers live in the :development
# group below and are only used if you deploy with the shipped config/deploy.rb.)
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
# tabs (set_tab / tabs_tag) are vendored in the inline_forms engine since
# 8.1.23 (InlineForms::Tabs) — the unmaintained tabs_on_rails gem is gone.
gem 'unicorn'
gem 'validation_hints', '~> 8'
gem 'will_paginate', '~> 4.0'

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
  # Rails 8 sqlite3 adapter requires sqlite3 >= 2.1.
  gem 'sqlite3', '>= 2.1'
  gem 'thin'
  gem 'yaml_db'
end

gem_group :production do
  gem 'mini_racer'
  gem 'uglifier'
end

say "- Running bundle..."
run "gem install bundler --no-document"
install_prerelease_gems_from_roots!
bundle_install!

say "- Dart Sass: inline_forms stylesheet entrypoints + initializer..."
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/inline_forms_dartsass_builds.rb"),
          "config/initializers/inline_forms_dartsass_builds.rb"
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/inline_forms_main.scss"),
          "app/assets/stylesheets/inline_forms_install/inline_forms_main.scss"
copy_file File.join(INSTALLER_ROOT, "lib/installer_templates/dartsass/devise_main.scss"),
          "app/assets/stylesheets/inline_forms_install/devise_main.scss"

say "- Sprockets: app/assets/config/manifest.js (Rails 8 importmap default omits it)..."
empty_directory "app/assets/config"
create_file "app/assets/config/manifest.js", <<~MANIFEST unless File.exist?("app/assets/config/manifest.js")
  //= link_tree ../images
  //= link_tree ../builds
MANIFEST

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

user_cfg = InlineFormsInstaller::UserModelConfig.from_env
unless user_cfg.default?
  say "- Auth model #{user_cfg.class_name} (#{user_cfg.table_name} table; Warden scope :user → current_user)", :green
end

say "- Create Devise route and add path_prefix..."

route <<-ROUTE.strip_heredoc
#{user_cfg.devise_route_line}
  resources :#{user_cfg.plural_route} do
    post 'revert', :on => :member
    get 'list_versions', :on => :member
end
ROUTE

say "- Create devise migration file"

sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "#{user_cfg.devise_migration_basename}.rb", <<-DEVISE_MIGRATION.strip_heredoc
class #{user_cfg.devise_migration_class} < ActiveRecord::Migration[8.1]

  def change
    create_table(:#{user_cfg.table_name}) do |t|
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

    add_index :#{user_cfg.table_name}, :email,                unique: true
    add_index :#{user_cfg.table_name}, :reset_password_token, unique: true
    # add_index :#{user_cfg.table_name}, :confirmation_token,   unique: true
    # add_index :#{user_cfg.table_name}, :unlock_token,         unique: true
  end
end
DEVISE_MIGRATION

say "- Create #{user_cfg.class_name} controller..."
create_file user_cfg.controller_path, <<-USERS_CONTROLLER.strip_heredoc
  class #{user_cfg.controller_name} < InlineFormsController
    set_tab :#{user_cfg.tab_key}
  end
USERS_CONTROLLER

say "- Create #{user_cfg.class_name} model..."
create_file user_cfg.model_path, <<-USER_MODEL.strip_heredoc
  class #{user_cfg.class_name} < ApplicationRecord

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

    #attr_accessible :email, :password, :locale, :remember_me

    belongs_to :locale
    has_and_belongs_to_many :roles

    # validations
    validates :name, :presence => true

    # Default ordering for inline_forms list views (and any explicit caller
    # via `#{user_cfg.class_name}.inline_forms_list`). Avoids `default_scope`
    # so callers can `unscope`/`reorder` cleanly when needed.
    scope :inline_forms_list, -> { order(:name, :id) }
    # Search box on /#{user_cfg.plural_route} filters by name OR email. Without this
    # the controller would `merge(ApplicationRecord.inline_forms_search(q))`,
    # which is the no-op `all` fallback, and the query string would be silently
    # ignored.
    scope :inline_forms_search, ->(q) { where("name LIKE :q OR email LIKE :q", q: "%\#{q}%") }

    def _presentation
      "\#{name}"
    end

    def role?(role)
      return !!self.roles.find_by_name(role)
    end

    def inline_forms_attribute_list
      @inline_forms_attribute_list ||= [
        [ :header_user_login,         :header ],
        [ :name,                      :text_field ],
        [ :email,                     :text_field ],
        [ :locale,                    :dropdown ],
        [ :password,                  :devise_password_field ],
        [ :header_user_roles,         :header ],
        [ :roles,                     :check_list ],
        [ :header_user_other_stuff,   :header ],
        [ :encrypted_password,        :info ],
        [ :reset_password_token,      :info ],
        [ :reset_password_sent_at,    :info ],
        [ :remember_created_at,       :info ],
        [ :sign_in_count,             :info ],
        [ :current_sign_in_at,        :info ],
        [ :last_sign_in_at,           :info ],
        [ :current_sign_in_ip,        :info ],
        [ :last_sign_in_ip,           :info ],
        [ :created_at,                :info ],
        [ :updated_at,                :info ],
      ]
    end

  end
USER_MODEL

# inline_forms initializer (must exist before subsequent `rails g inline_forms`
# runs so the generator's `add_tab` step can inject each generated model's
# route token into `MODEL_TABS`). Pre-seeded with the user-model route
# (the user model is hand-written above, not generated, so the generator
# never sees it).
say "- Creating inline_forms initializer (MODEL_TABS seeded with #{user_cfg.plural_route})"
create_file "config/initializers/inline_forms.rb", <<-END_INITIALIZER.strip_heredoc
  Rails.application.reloader.to_prepare do
    MODEL_TABS = %w(#{user_cfg.plural_route} )
  end
END_INITIALIZER

# Create Locales
say "- Create locales"
generate "inline_forms", "Locale name:string title:string #{user_cfg.table_name}:has_many _enabled:yes _list_order:title _presentation:\#{title}"
# Seed four locales so the FormElementShowcase HABTM :locales demo
# (added under --example) has something to check on/off. `id: 1` (en) is
# the default the admin user is bound to in the line below; the other
# three are inert until selected by the showcase rows.
append_to_file "db/seeds.rb", <<~LOCALE_SEED
  Locale.create({ id: 1, name: 'en', title: 'English' })
  Locale.create({ id: 2, name: 'nl', title: 'Nederlands' })
  Locale.create({ id: 3, name: 'de', title: 'Deutsch' })
  Locale.create({ id: 4, name: 'fr', title: 'Français' })
LOCALE_SEED

# Create Roles
say "- Create roles"
generate "inline_forms", "Role name:string description:text #{user_cfg.table_name}:has_and_belongs_to_many _enabled:yes _list_order:name _presentation:\#{name}"
append_to_file "db/seeds.rb", "Role.create({ id: 1, name: 'superadmin', description: 'Super Admin can access all.' })\n"

# Create Admin User

say "- Adding admin #{user_cfg.class_name.downcase} with email: #{ENV['email']}, password: #{ENV['password']} to seeds.rb"
append_to_file "db/seeds.rb", "#{user_cfg.class_name}.create({ id: 1, email: '#{ENV['email']}', locale_id: 1, name: 'Admin', password: '#{ENV['password']}', password_confirmation: '#{ENV['password']}' })\n"


sleep 1 # to get unique migration number
create_file "db/migrate/" +
  Time.now.utc.strftime("%Y%m%d%H%M%S") +
  "_" +
  "#{user_cfg.join_migration_basename}.rb", <<-ROLES_MIGRATION.strip_heredoc
  class #{user_cfg.join_migration_class} < ActiveRecord::Migration[8.1]
    def self.up
      create_table  :#{user_cfg.join_table}, :id => false, :force => true do |t|
        t.integer   :role_id
        t.integer   :#{user_cfg.foreign_key}
      end
      execute 'INSERT INTO #{user_cfg.join_table} VALUES (1,1);'
    end

    def self.down
      drop_table #{user_cfg.join_table}
    end
  end
ROLES_MIGRATION


say "- Installaing ZURB Foundation..."
#generate "foundation:install", "-f"

say "- Copy inline_forms_devise file for custom styles..."
copy_file File.join(INLINE_FORMS_ROOT, 'lib/generators/assets/stylesheets/inline_forms_devise.css'), 'app/assets/stylesheets/inline_forms_devise.css'

say "- Sprockets: link inline_forms_devise.css (logical path; dartsass:install drops link_directory ../stylesheets)..."
append_to_file "app/assets/config/manifest.js", "//= link inline_forms_devise.css\n"

say "- Install ApplicationRecord (PaperTrail, pagination, inline_forms defaults)..."
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
#
# date/time `_select` columns (e.g. FormElementShowcase#meeting_time, a
# `:time_select` backed by a :time column) serialize their changeset value as
# an `ActiveRecord::Type::Time::Value` (and the Date/DateTime siblings for
# `:date_select` / datetime columns). Those wrapper classes must also be
# permitted or `version.changeset` raises `Psych::DisallowedClass: Tried to
# load unspecified class: ActiveRecord::Type::Time::Value` on the revert /
# versions-panel path.
create_file 'config/initializers/paper_trail_yaml_safe_load.rb', <<-PT_YAML.strip_heredoc
  # Generated by inline_forms.
  # See https://github.com/paper-trail-gem/paper_trail and
  # ActiveRecord::Coders::YAMLColumn safe-loading rules.
  permitted = [
    Symbol,
    Date,
    Time,
    BigDecimal,
    ActiveSupport::TimeWithZone,
    ActiveSupport::TimeZone,
    ActiveSupport::HashWithIndifferentAccess
  ]

  # date/time `_select` columns serialize their PaperTrail changeset/object
  # value under a type-specific wrapper class — e.g. a `:time_select` helper
  # maps to a `:time` column whose cast value is an
  # `ActiveRecord::Type::Time::Value` (a Time subclass). Psych matches the
  # *exact* stored class name, so permitting `Time`/`Date` is not enough: the
  # wrapper must be listed too, or `revert` (`version.reify`) and the versions
  # panel (`version.changeset`) raise/swallow Psych::DisallowedClass. Resolve
  # by name and skip any this Rails version does not define (only Time::Value
  # exists today; Date/DateTime are listed defensively for forward-compat).
  %w[
    ActiveRecord::Type::Time::Value
    ActiveRecord::Type::Date::Value
    ActiveRecord::Type::DateTime::Value
  ].each do |const_name|
    klass = const_name.safe_constantize
    permitted << klass if klass
  end

  Rails.application.config.active_record.yaml_column_permitted_classes ||= []
  Rails.application.config.active_record.yaml_column_permitted_classes |= permitted
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

      user ||= #{user_cfg.class_name}.new # guest user

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
  run 'bundle exec rails g inline_forms Photo name:string caption:string image:image_field description:rich_text apartment:belongs_to _list_order:name _presentation:\'#{name}\''
  run 'bundle exec rails generate uploader Image'
  run 'bundle exec rails g inline_forms Apartment name:string title:string opening_date:date description:rich_text photos:has_many photos:associated _enabled:yes _list_order:name _list_search:name _presentation:\'#{name}\''

  say "- Apartment name is required..."
  inject_into_file "app/models/apartment.rb",
                   "\n  validates :name, presence: true\n",
                   after: "class Apartment < ApplicationRecord\n"

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
  inject_into_class "app/models/photo.rb", "Photo", "  self.per_page = 5\n"

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
  run %q{bundle exec rails g inline_forms Owner name:string birthdate:date address:string city:string country:string apartments:has_many apartments:associated _enabled:yes _list_order:name _list_search:name _presentation:'#{name}'}

  say "- Owner name is required..."
  inject_into_file "app/models/owner.rb",
                   "\n  validates :name, presence: true\n",
                   after: "class Owner < ApplicationRecord\n"

  say "- Adding owner_id to apartments + belongs_to :owner..."
  sleep 1
  add_owner_ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{add_owner_ts}_add_owner_to_apartments.rb", <<-ADD_OWNER.strip_heredoc
    class AddOwnerToApartments < ActiveRecord::Migration[8.1]
      def change
        add_reference :apartments, :owner, null: true, foreign_key: true
      end
    end
  ADD_OWNER

  inject_into_file "app/models/apartment.rb",
                   "  belongs_to :owner, optional: true\n",
                   after: "class Apartment < ApplicationRecord\n"

  # Insert the :owner dropdown row at the top of Apartment's attribute list
  # so it appears above :name in the inline panel.
  gsub_file "app/models/apartment.rb",
            /@inline_forms_attribute_list \|\|= \[\n/,
            "@inline_forms_attribute_list ||= [\n     [ :owner, :dropdown ], \n"

  # Owner -> apartments: render as a check_list of EXISTING apartments
  # (not the default :associated panel that only lets you create new
  # rows nested under the owner). Standard Rails has_many gives us the
  # `apartment_ids=` setter that CheckListHelper uses, so we just swap
  # the form element kind in the generated attribute list.
  gsub_file "app/models/owner.rb",
            /\[ :apartments, :associated \]/,
            '[ :apartments, :check_list ]'

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
          full.find { |a, _| a == attr } ||
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
    class SeedExampleApartmentsAndOwners < ActiveRecord::Migration[8.1]
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

  # ---------------------------------------------------------------------
  # FormElementShowcase: a fourth example resource that exercises every
  # kept Tier 1 form_element helper on a single object. The kept set
  # (and the rationale for what was dropped) is documented in
  # stuff/form-element-showcase-plan.md. The runtime helpers handle
  # every element generically; this block wires up the model, value
  # rows, uploaders, join table, and seed data.
  # ---------------------------------------------------------------------
  say "- Generating FormElementShowcase (one resource per kept Tier 1 form_element)..."
  sleep 1
  run %q{bundle exec rails g inline_forms FormElementShowcase title:string body_plain_area:plain_text_area count:integer_field price:decimal_field amount:money_field latitude:decimal_field{9,6} longitude:decimal_field{10,6} meeting_date:date_select meeting_time:time_select birth_month:month_select start_month:month_year_picker is_active:check_box gender:radio_button rating_int:dropdown_with_integers priority:dropdown_with_values priority2:dropdown_with_values stars:dropdown_with_values_with_stars scale_int:scale_with_integers scale_val:scale_with_values attachment:file_field jingle:audio_field cover:image_field description:rich_text locales:has_and_belongs_to_many _enabled:yes _list_order:title _list_search:title _presentation:'#{title}'}

  say "- Generating Attachment + Jingle uploaders (Cover reuses ImageUploader)..."
  run "bundle exec rails generate uploader Attachment"
  run "bundle exec rails generate uploader Jingle"

  # Cover reuses ImageUploader (already generated for Photo). CarrierWave
  # is happy to mount one uploader class on multiple models; the global
  # `remove_previously_stored_files_after_update = false` keeps PaperTrail
  # revertable for both.
  gsub_file "app/models/form_element_showcase.rb",
            "mount_uploader :cover, CoverUploader",
            "mount_uploader :cover, ImageUploader"

  # money-rails wiring for the `amount:money_field` showcase column.
  #
  #   * The inline_forms generator emits a plain `t.integer :amount`
  #     (FormElementRegistry maps `:money_field` to `:integer`), but
  #     money-rails' `monetize` reader/writer convention is `_cents`-
  #     suffixed: declare `monetize :amount_cents`, store cents in
  #     `amount_cents`, and money-rails defines `obj.amount`/`obj.amount=`
  #     returning/parsing Money objects. That keeps the inline_forms
  #     attribute list entry `[:amount, :money_field]` semantically
  #     correct (`obj.amount` => Money) without a custom helper.
  #   * Rename the column in the generated create-table migration from
  #     `:amount` to `:amount_cents` *before* `rake db:migrate` runs.
  #   * Add a small initializer pinning the default currency so the
  #     showcase renders predictably under any host locale.
  showcase_migration = Dir.glob("db/migrate/*_inline_forms_create_form_element_showcases.rb").first
  if showcase_migration
    gsub_file showcase_migration, /t\.integer :amount\b/, "t.integer :amount_cents, default: 0, null: false"
  end

  create_file "config/initializers/money.rb", <<-MONEY_INIT.strip_heredoc
    # Generated by inline_forms (money-rails defaults for the
    # FormElementShowcase `amount:money_field` demo column).
    MoneyRails.configure do |config|
      config.default_currency = :usd
    end
  MONEY_INIT

  # First field-level validation in the example app. `allow_blank: true`
  # keeps PaperTrail revert paths (and the seeded second row, which leaves
  # count nil) valid. The integration test covers the explicit error
  # path by POSTing `count: "abc"` to /form_element_showcases.
  #
  # `locales_display` is a virtual alias for the HABTM :locales association
  # so the same association can render twice in the attribute list: once
  # editable (`[:locales, :check_list]`) and once read-only
  # (`[:locales_display, :info_list]`). Inline-forms keys turbo frames by
  # attribute name, so we need a distinct name for the second row — info_list
  # has no `_update` method, hence the wrapper rather than a separate column.
  #
  # NOTE: this has to be `def locales_display; locales; end`, not
  # `alias_method :locales_display, :locales`. `alias_method` resolves the
  # source method at class-load time, but the `has_and_belongs_to_many
  # :locales` declaration that defines `#locales` is injected lower in the
  # file (line ~12), so an alias_method here raises
  # `NameError: undefined method 'locales' for class 'FormElementShowcase'`.
  # A `def` body is parsed but only resolved at call time, side-stepping
  # the ordering hazard.
  inject_into_file "app/models/form_element_showcase.rb",
                   "\n  validates :count, numericality: { only_integer: true }, allow_blank: true\n" \
                   "  validates :price, numericality: true, allow_blank: true\n" \
                   "  validates :latitude,  numericality: { greater_than_or_equal_to:  -90, less_than_or_equal_to:  90 }, allow_blank: true\n" \
                   "  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_blank: true\n" \
                   "  mount_uploader :attachment, AttachmentUploader\n  monetize :amount_cents\n\n  def locales_display\n    locales\n  end\n",
                   after: "class FormElementShowcase < ApplicationRecord\n"

  # Value-bearing rows for every form_element that needs a values hash
  # (or hash + options_disabled). 8.1.5 row shape: [:attr, :form_element]
  # for bare rows, [:attr, :form_element, values, options_disabled] for
  # choice rows.
  showcase_value_rows = {
    "[ :is_active, :check_box ]"                       => "[ :is_active, :check_box, { 0 => 'no', 1 => 'yes' } ]",
    "[ :gender, :radio_button ]"                       => "[ :gender, :radio_button, { 1 => 'male', 2 => 'female' } ]",
    "[ :rating_int, :dropdown_with_integers ]"         => "[ :rating_int, :dropdown_with_integers, { 1 => 'one', 2 => 'two', 3 => 'three' } ]",
    "[ :priority, :dropdown_with_values ]"             => "[ :priority, :dropdown_with_values, { 1 => 'low', 2 => 'mid', 3 => 'high' } ]",
    "[ :priority2, :dropdown_with_values ]"            => "[ :priority2, :dropdown_with_values, { 1 => 'low', 2 => 'mid', 3 => 'high' }, [ 2 ] ]",
    "[ :stars, :dropdown_with_values_with_stars ]"     => "[ :stars, :dropdown_with_values_with_stars, { 1 => '1stars', 2 => '2stars', 3 => '3stars', 4 => '4stars', 5 => '5stars' } ]",
    "[ :scale_int, :scale_with_integers ]"             => "[ :scale_int, :scale_with_integers, { 1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four', 5 => 'five' } ]",
    "[ :scale_val, :scale_with_values ]"               => "[ :scale_val, :scale_with_values, { 1 => 'red', 2 => 'green', 3 => 'blue' } ]",
  }
  showcase_value_rows.each do |from, to|
    gsub_file "app/models/form_element_showcase.rb", from, to
  end

  # Section headers + the trailing info/info_list block. `roles` is a
  # has_and_belongs_to_many relation so the generator skips its
  # attribute_list row; we hand-insert it as `:info_list` (read-only
  # checklist of role _presentation strings).
  showcase_header_inserts = {
    "[ :title, :text_field ],"                  => "[ :header_basics, :header ], \n     [ :title, :text_field ],",
    "[ :count, :integer_field ],"               => "[ :header_numbers, :header ], \n     [ :count, :integer_field ],",
    "[ :meeting_date, :date_select ],"          => "[ :header_dates, :header ], \n     [ :meeting_date, :date_select ],",
    "[ :is_active, :check_box, { 0 => 'no'"     => "[ :header_choices, :header ], \n     [ :is_active, :check_box, { 0 => 'no'",
    "[ :attachment, :file_field ],"             => "[ :header_files, :header ], \n     [ :attachment, :file_field ],",
    "[ :description, :rich_text ],"             => "[ :header_rich, :header ], \n     [ :description, :rich_text ],",
  }
  showcase_header_inserts.each do |from, to|
    gsub_file "app/models/form_element_showcase.rb", from, to
  end

  # Insert :locales (editable check_list), :locales_display (read-only
  # info_list mirror of the same association — see the alias_method
  # above), :header_meta, and the timestamps after the rich_text row.
  # The generator does not emit a row for `locales:has_and_belongs_to_many`
  # (relation? is true), so we add the rows manually here. Locale (not
  # Role) was chosen because Role is reserved for the user/Member model
  # in the inline_forms example app (the join sits under roles_users);
  # Locale already has a `_presentation` returning `title`, which is
  # exactly what `info_list_show` renders per row.
  gsub_file "app/models/form_element_showcase.rb",
            "[ :description, :rich_text ], \n",
            "[ :description, :rich_text ], \n     [ :locales, :check_list ], \n     [ :locales_display, :info_list ], \n     [ :header_meta, :header ], \n     [ :created_at, :info ], \n     [ :updated_at, :info ], \n"

  # Locale keys for the showcase attributes. Headers + the timestamps
  # need explicit labels so `human_attribute_name` does not fall back to
  # "Header basics" / "Created at". The leading two-space indent puts
  # the `activerecord:` key under the existing `en:` root.
  showcase_locale = <<~END_SHOWCASE_LOCALE
    activerecord:
      attributes:
        form_element_showcase:
          header_basics: Basics
          header_numbers: Numbers
          header_dates: Dates and times
          header_choices: Choices and scales
          header_files: Files
          header_rich: Rich text
          header_meta: Metadata
          title: Title
          body_plain_area: Plain text area
          count: Count
          price: Price
          amount: Amount
          meeting_date: Meeting date
          meeting_time: Meeting time
          latitude: Latitude
          longitude: Longitude
          birth_month: Birth month
          start_month: Start month and year
          is_active: Is active
          gender: Gender
          rating_int: Rating
          priority: Priority
          priority2: Priority (with disabled option)
          stars: Stars
          scale_int: Scale (integers)
          scale_val: Scale (values)
          attachment: Attachment
          jingle: Jingle
          cover: Cover
          description: Description
          locales: Locales (editable)
          locales_display: Locales (read-only)
          created_at: Created at
          updated_at: Updated at
  END_SHOWCASE_LOCALE
  append_to_file "config/locales/inline_forms_local.en.yml", showcase_locale.lines.map { |l| "  #{l}" }.join

  # Star images for dropdown_with_values_with_stars. The runtime helper
  # calls `image_tag("\#{n}stars.png")`, so we ship 5 tiny PNGs in
  # lib/installer_templates/example_app_assets and copy them into
  # app/assets/images at install time.
  showcase_assets_root = File.join(INSTALLER_ROOT, "lib/installer_templates/example_app_assets")
  (1..5).each do |n|
    src = File.join(showcase_assets_root, "#{n}stars.png")
    copy_file src, File.join("app/assets/images", "#{n}stars.png") if File.exist?(src)
  end

  # File/audio/image upload sample assets for the full-demo seed. Copied
  # under db/seed_uploads so the seed migration can read them at
  # db:migrate time and store them through CarrierWave. Mirrors the
  # db/seed_images convention used for the Photo gallery seed above.
  %w[sample.txt sample.wav sample_cover.png].each do |basename|
    src = File.join(showcase_assets_root, basename)
    copy_file src, File.join("db/seed_uploads", basename) if File.exist?(src)
  end

  # Join table for has_and_belongs_to_many :locales. Mirrors the
  # roles_users join migration created for the user model above. Locale
  # (not Role) was chosen because Role is reserved for the Member/User
  # auth model; using it here would coincidentally share the same join
  # row pool as roles_users which is confusing for the demo. The four
  # locales seeded above (en/nl/de/fr) give the editable check_list
  # something interesting to toggle.
  say "- Creating form_element_showcases_locales join migration..."
  sleep 1
  habtm_ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{habtm_ts}_create_join_table_form_element_showcases_locales.rb", <<-HABTM_MIGRATION.strip_heredoc
    class CreateJoinTableFormElementShowcasesLocales < ActiveRecord::Migration[8.1]
      def self.up
        create_table :form_element_showcases_locales, id: false, force: true do |t|
          t.integer :form_element_showcase_id
          t.integer :locale_id
        end
      end

      def self.down
        drop_table :form_element_showcases_locales
      end
    end
  HABTM_MIGRATION

  # Seed two showcase rows: one fully populated (so every show branch
  # has data), and one with no roles + no uploads (so info_list's empty
  # branch and the uploader empty branches render). Idempotent.
  say "- Creating FormElementShowcase seed migration..."
  sleep 1
  showcase_seed_ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{showcase_seed_ts}_seed_form_element_showcases.rb", <<-SHOWCASE_SEED.strip_heredoc
    class SeedFormElementShowcases < ActiveRecord::Migration[8.1]
      def up
        return unless defined?(FormElementShowcase)

        full = FormElementShowcase.find_or_create_by!(title: "Full demo") do |s|
          s.body_plain_area = "A short plain-text paragraph."
          s.count           = 7
          s.price           = "12.34"
          s.amount          = Money.from_amount(99.95, "USD") if s.respond_to?(:amount=)
          # Curaçao (Willemstad). Exactly representable in decimal(9,6)
          # and decimal(10,6) — useful for the precision-survival test
          # that asserts the round-trip is bit-identical, not float-fuzzy.
          s.latitude        = BigDecimal("12.123456")
          s.longitude       = BigDecimal("-68.987654")
          s.meeting_date    = Date.new(2026, 6, 1)
          s.meeting_time    = Time.utc(2000, 1, 1, 14, 30)
          s.birth_month     = 7
          s.start_month     = Date.new(2026, 9, 1)
          s.is_active       = true
          s.gender          = 1
          s.rating_int      = 2
          s.priority        = 2
          s.priority2       = 3
          s.stars           = 4
          s.scale_int       = 3
          s.scale_val       = 2
          s.description     = "<p>A rich-text paragraph for the showcase.</p>"
        end
        # Attach the default locale (en) so the editable check_list and the
        # paired read-only info_list both have something to show. The other
        # seeded locales (nl/de/fr) stay unchecked so the toggle UX is
        # exercised when the user opens the check_list.
        if defined?(Locale) && Locale.exists?(1) && full.locales.empty?
          full.locales << Locale.find(1)
        end

        # File/audio/image uploads for the full demo. The asset files are
        # copied into db/seed_uploads/ from lib/installer_templates/example_app_assets/
        # at install time (see the asset-copy block above), so this
        # migration can open them at db:migrate time and hand File handles
        # to CarrierWave for storage in public/uploads/.
        seed_uploads = Rails.root.join("db", "seed_uploads")
        {
          attachment: seed_uploads.join("sample.txt"),
          jingle:     seed_uploads.join("sample.wav"),
          cover:      seed_uploads.join("sample_cover.png"),
        }.each do |attr, path|
          next unless path.file?
          next if full.public_send(attr).present?
          File.open(path, "rb") { |io| full.public_send("\#{attr}=", io) }
        end
        full.save! if full.changed?

        # "Empty" refers to the role and uploader fields (their empty
        # branches need to render). The other fields keep valid values
        # because several show helpers (e.g. dropdown_with_integers) raise
        # on nil/out-of-range integers.
        FormElementShowcase.find_or_create_by!(title: "Empty demo") do |s|
          s.is_active  = false
          s.gender     = 1
          s.rating_int = 1
          s.priority   = 1
          s.priority2  = 1
          s.stars      = 1
          s.scale_int  = 1
          s.scale_val  = 1
        end
      end

      def down
        return unless defined?(FormElementShowcase)
        FormElementShowcase.where(title: ["Full demo", "Empty demo"]).destroy_all
      end
    end
  SHOWCASE_SEED

  say "- Running showcase migrations (create table + join + seed)..."
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
  example_user_cfg = InlineFormsInstaller::UserModelConfig.from_env
  Dir.glob(File.join(example_tests_root, "**", "*.rb")).sort.each do |abs|
    rel = abs.delete_prefix(example_tests_root + File::SEPARATOR).tr("\\", "/")
    create_file rel, example_user_cfg.adapt_example_test_source(File.read(abs))
  end

  # Cap test parallelism so the example-app gate fits on memory-modest
  # machines. Rails' minitest parallelizer defaults to `workers:
  # number_of_processors`, which on a 20-core box forks 20 full Rails
  # processes — each ~200-300 MB resident with the example app's full
  # gem stack (CarrierWave + Devise + PaperTrail + Foundation +
  # tabs_on_rails + money-rails). Multiply that by 20 and you're 4-6 GB
  # in worker processes alone, on top of the parent installer/bundler
  # state. On a memory-pressured host systemd-oomd can kill the whole
  # VTE/terminal session before the gate finishes, with no useful
  # signal back to the user (one such kill happened mid-gate on
  # 2026-05-28 07:50:35; that's what motivated this cap).
  #
  # `PARALLEL_WORKERS=2` keeps the worker footprint to ~600 MB and
  # roughly doubles the wall-clock vs 20 workers — fine for a one-shot
  # gate. The `INLINE_FORMS_TEST_WORKERS` env override lets machines
  # with RAM headroom crank it back up (use `0` for Rails' default
  # number_of_processors, any positive integer to pin).
  workers_env = ENV["INLINE_FORMS_TEST_WORKERS"].to_s.strip
  workers     = if workers_env.empty?
                  "2"
                elsif workers_env == "0"
                  nil  # let Rails pick number_of_processors
                else
                  workers_env
                end
  worker_prefix = workers ? "PARALLEL_WORKERS=#{Shellwords.escape(workers)} " : ""

  say "- Running example regression tests (bundle exec rails test)#{workers ? " with PARALLEL_WORKERS=#{workers}" : ""}..."
  log_path = ENV["INLINE_FORMS_INSTALLER_LOG"].to_s
  rails_test = "#{worker_prefix}bundle exec rails test"
  test_cmd = if log_path != ""
               "#{rails_test} 2>&1 | tee -a #{Shellwords.escape(log_path)}"
             else
               "#{rails_test} 2>&1"
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
