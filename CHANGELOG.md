# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [7.0.0] - 2026-05-05

### Changed

- **Target Rails 7.0.x**. `inline_forms.gemspec` now requires `rails >= 7.0.0, < 7.1`. Upgrades the gem from the Rails 6.1 / Webpacker era to the Rails 7.0 / importmap era.
- **Generated app Gemfile (`bin/inline_forms_installer_core.rb`)**: `gem 'rails', '~> 7.0.0'` (was `'6.1.3.1'`); add explicit `gem 'sprockets-rails'` (no longer in the default Rails 7 Gemfile but required by the gem's own `app/assets`); add `gem 'importmap-rails'` for the new default JS pipeline; drop `gem 'coffee-rails'` (unused by the gem itself, dead default in Rails 7).
- **`bin/inline_forms`**: `rails new` invocation drops `--skip-gemfile` (Rails 7 removed it) and `--skip-test-unit` (renamed in Rails 5; we let the default test scaffolding run in Rails 7 so `test/test_helper.rb` exists for the example app's regression tests). Adds `--javascript=importmap` so the generated app explicitly opts into Hotwire/importmap-rails (default in Rails 7, made explicit for clarity).
- **Generator migration template (`lib/generators/templates/migration.erb`)**: emits `ActiveRecord::Migration[7.0]`.
- **Installer migrations (`bin/inline_forms_installer_core.rb`)**: `DeviseCreateUsers`, `InlineFormsCreateJoinTableUserRole` and `InlineFormsCreateViewForTranslations` now use `ActiveRecord::Migration[7.0]`.
- **Generator unit tests (`test/inline_forms_generator_test.rb`)**: assert against `ActiveRecord::Migration[7.0]`.

### Fixed

- **Gemfile conflict on Rails 7 (`bin/inline_forms_installer_core.rb`)**: explicit `remove_file 'Gemfile'` before `create_file 'Gemfile'` so the installer template no longer prompts to overwrite the Gemfile that `rails new` (Rails 7) always creates.
- **Custom field types under Rails 7 (`lib/generators/inline_forms_generator.rb`)**: override `Rails::Generators::GeneratedAttribute.valid_type?` to always accept incoming types. Rails 7 removed the rescue around `ActiveRecord::Base.connection.valid_type?`, so the parser raised `NameError`/`Could not generate field` for our custom types (`:dropdown`, `:check_list`, `:image_field`, `:rich_text`, ...) and broke generator unit tests that don't load Active Record. Unknown-type detection still happens later via Thor::Error + `--allow-unknown`.

### Notes / known issues

- PaperTrail (currently sourced from the `acesuares/paper_trail` fork at v12.0.0) prints a "not compatible with ActiveRecord 7.0" warning on boot. Tests pass and the example app works end-to-end. A follow-up bump to PaperTrail 13+ is recommended but not required.

## [6.4.1] - 2026-05-05

### Fixed

- **`rich_text` form element (`app/helpers/form_elements/rich_text.rb`)**: `rich_text_edit` no longer relies on the non-existent `rich_text_area_tag` (Rails 6.1) which produced an empty cell on new and existing records. It now renders a hidden input + `<trix-editor>` pair tied by `input=` so the editor actually shows up inline.
- **`rich_text_show`**: more defensive handling of nil/blank ActionText values (uses `to_plain_text` when available) so the `+` placeholder shows on empty values and the rendered HTML shows on populated ones.

### Changed

- **Inline edit layout (`app/views/inline_forms/_edit.html.erb`)**: added `rich_text` to `@BUTTONS_UNDER` so the editor gets a full-width row with OK/Cancel below it (matching `text_area`).
- **Layouts (`app/views/layouts/{application,inline_forms}.html.erb`)**: include Trix 1.3.1 CSS+JS from unpkg so generated apps render the editor without bundling JS, and keep the existing CKEditor guard.

## [6.4.0] - 2026-05-05

### Added

- **New `rich_text` form element** (`app/helpers/form_elements/rich_text.rb`) for ActionText-backed attributes, including show/edit/update/info handlers compatible with inline editing.
- **Generator coverage** for ActionText declarations in `test/inline_forms_generator_test.rb` (`content:rich_text` emits `has_rich_text` and skips migration column generation).
- **Reusable workflow prompt docs** in `docs/prompt/test-the-example-app.md` with a local `docs/prompt/.gitignore`.

### Changed

- **Inline forms generator** now emits `has_rich_text :attribute` in generated models when the field type is `:rich_text` (`lib/generators/inline_forms_generator.rb`, `lib/generators/templates/model.erb`).
- **Installer template** moved generated apps from CKEditor setup to ActionText migrations (`active_storage:install` + `action_text:install:migrations`) and updates example resources to use `description:rich_text`.
- **Generated app Gemfile wiring** now points `inline_forms` to the local gem path during scaffold/install flow, so iteration testing uses current local code.

### Fixed

- **Layouts** no longer raise `uninitialized constant Ckeditor` when CKEditor is absent: CKEditor CDN script tags are now conditional in `app/views/layouts/application.html.erb` and `app/views/layouts/inline_forms.html.erb`.

## [6.3.4] - 2026-05-05

### Added

- **Generator regression harness** in `test/inline_forms_generator_test.rb` that runs `InlineForms::InlineFormsGenerator` against a temporary destination and asserts generated model/controller/route/migration output plus `_no_model` behavior.
- **Same:** coverage for unknown-type handling, including default strict mode and the explicit legacy opt-out via `--allow-unknown`.

### Changed

- **Generator hardening (`lib/generators/inline_forms_generator.rb`):** unknown field types now fail fast by default with a clear message listing the offending `name:type` pairs and how to opt into legacy behavior.

### Fixed

- **Same:** internal control attributes prefixed with `_` (such as `_no_model`, `_enabled`, `_no_migration`, `_id`) are excluded from unknown-type checks, so generator flags keep working under strict validation.
- **Generator tests (`test/inline_forms_generator_test.rb`):** require `logger` before `rails` so Bundler-based test runs are stable on Rails 6.1 / Ruby 3.2.

## [6.3.3] - 2026-05-03

### Added

- **`--example` installs regression tests** under `test/example_app/` and `test/integration/example_app_*_test.rb`, plus model coverage for the generated Photo/Apartment resources. Run them with **`bundle exec rails test`** in the new app.

### Changed

- **Example installer** no longer runs **`bundle exec rails s`** at the end (it blocked the shell). Start the server manually when you want to use the browser.

### Fixed

- **Sqlite `database.yml`** now includes a **`test`** database (`db/test.sqlite3`) so **`bundle exec rails test`** works in generated sqlite apps.
- Generated apps add a **`test`** Bundler group with **`minitest ~> 5.25`** so Rails 6.1’s test runner stays compatible (avoids Minitest 6 / **`railties`** **`line_filtering`** and parallelization API mismatches).

## [6.3.2] - 2026-05-03

### Fixed

- **Application template (`bin/inline_forms_installer_core.rb`):** generated apps use **`rails-i18n ~> 7.0`** from RubyGems instead of the **`svenfuchs/rails-i18n`** git default branch, which targets Rails 8+ and could not be resolved with pinned **`rails` 6.1.3.1**.
- **Same:** development **`sqlite3`** is pinned to **`~> 1.4`** so it matches ActiveRecord 6.1’s adapter expectation (avoids **`sqlite3` 2.x** activation errors during generators and boot).
- **Same:** **`sleep 1`** after **`paper_trail:install`** (two migrations in one second) and between translation **`inline_forms`** generators so migration version numbers stay unique.
- **Same:** when **`using_sqlite`** is true, run **`paper_trail:install --with-changes`** only (omit **`--with-mysql`**). The MySQL/InnoDB table options in the PaperTrail migration are invalid on SQLite and broke **`db:migrate`** for the sqlite example app.

## [6.3.1] - 2026-05-03

### Changed

- `**InlineFormsHelper#link_to_inline_edit**` uses `**edit_polymorphic_path**` instead of `**send('edit_' + object.class.to_s.underscore + '_path', …)**`.
- `**InlineFormsHelper#close_link**` and `**#link_to_destroy**` use `**polymorphic_path(object, …)**` instead of `**send(object.class.to_s.underscore + '_path', …)**`.
- Partial templates `**_close.html.erb**`, `**_edit.html.erb**`, and `**_new.html.erb**` use `**polymorphic_path**` for member and collection URLs instead of building helper names with `**send**`.
- `**_edit.html.erb**` form and cancel links now pass the record into `**polymorphic_path(@object, …)**` so the member path includes the resource id (required for conventional `**resources**` routes).

### Compatibility

- Intended to be **non-breaking** for typical ActiveRecord models with standard `**resources :model**` routing: URLs match Rails’ named helpers (`**edit_*_path**`, `**article_path**`, `**articles_path**`, etc.). Paths are derived from `**model_name**` / `**singular_route_key**` instead of `**class.name.underscore**`, which can differ only in unusual setups (e.g. a custom `**model_name**` that does not match the previous string).

### Development

- `**test/inline_edit_polymorphic_path_test.rb**` asserts parity between polymorphic helpers and named `**edit_article_path**`, `**article_path**`, and `**articles_path**` for a minimal `**resources :articles**` route set (no full app boot).

## [6.3.0] - 2026-05-03

### Removed

- Project-specific `absence_list` form element (`app/helpers/form_elements/absence_list.rb`). Applications that still need it should copy the old implementation into their own codebase.

### Changed

- `**InlineFormsHelper#link_to_inline_edit**` now requires keyword argument `**from_callee:**` (pass `**__callee__**` from the enclosing `*_show` method). The form element name for the edit request is derived with `String#delete_suffix('_show')` after stripping a leading `block in`  prefix when present. This replaces stack inspection via `Kernel#calling_method` / `caller` parsing.
- `**Kernel` patches** for `this_method` and `calling_method` were removed from `lib/inline_forms.rb` and `app/helpers/inline_forms_helper.rb`.

### Upgrade notes

- **Breaking:** Any custom code that called `link_to_inline_edit` with a fourth positional `form_element` argument must switch to `from_callee: __callee__` when the call is made from a `*_show` helper, or pass the appropriate callee symbol for your naming convention.
- **Breaking:** Models or apps that referenced the `absence_list` form element from this gem must drop that reference or vendor the removed helper.

### Development

- Run `bundle install` then `rake` (or `rake test`) to execute Minitest for `InlineForms.form_element_string_from_callee` (no Rails boot). The Rake task uses verbose mode so each test prints on its own line; failed assertions show the explanatory message from the test file.
- For end-to-end checks, generate a disposable app with `**bin/inline_forms create MyApp -d sqlite`** (uses RVM unless `--no-rvm`), or add the gem with `**gem "inline_forms", path: "/path/to/inline_forms"**` in a Rails app’s Gemfile, run `**rails g inline_forms …**`, migrate, and exercise the UI in the browser.