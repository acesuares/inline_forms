# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [7.1.2] - 2026-05-05

### Added

- **Turbo (Hotwire) is now loaded in generated apps as an ES module**, completing rollout step 1 of `stuff/ujs-to-turbo.md` (gitignored): "Installer + reference app: Turbo wired end-to-end (layout, importmap, one smoke flow)". Both layouts (`app/views/layouts/inline_forms.html.erb`, `app/views/layouts/application.html.erb`) emit a `<script type="module">` immediately after the existing Sprockets `javascript_include_tag` that does `import { Turbo } from "<%= asset_path('turbo.min.js') %>"` and then `Turbo.session.drive = false`. `turbo.min.js` is already on the asset path (and on `config.assets.precompile`) via the `turbo-rails` gem (`Turbo::Engine`'s `turbo.assets` initializer adds `turbo.js`, `turbo.min.js`, `turbo.min.js.map` to `PRECOMPILE_ASSETS`), so no extra installer wiring is required.
- **Smoke test (`test/integration/example_app_turbo_layout_test.rb` in `--example` apps)**: signs in and `GET /apartments`, asserting the rendered HTML contains the `<script type="module">` import of `turbo.min.js` and the `Turbo.session.drive = false` line. Catches regressions where a layout edit drops the Turbo import (which would silently cause future `<turbo-frame>` conversions to fall back to full-page navigation).

### Changed

- **`app/assets/javascripts/inline_forms/inline_forms.js`**: updated the long Turbo comment to reflect that Turbo is now loaded by the layout as `<script type="module">` (with Drive disabled), instead of describing the `//= require turbo` regression as something deferred. The Sprockets bundle itself is unchanged: still `jquery`, `jquery_ujs`, `jquery.ui.all`, `jquery.timepicker`, `foundation`, `jquery.remotipart`, `autocomplete-rails`.
- **`lib/inline_forms/version.rb`**: `7.1.1` → `7.1.2`.

### Notes

- Drive is disabled (`Turbo.session.drive = false`) on purpose: every existing inline_forms link/form is still UJS (`remote: true` + `format.js` + `*.js.erb`) and Turbo Drive intercepting those requests (sending `Accept: text/html, application/xhtml+xml`) would re-trigger the same `ActionController::UnknownFormat` failure 7.1.1 fixed. With Drive off, Turbo is dormant for navigation; the `<turbo-frame>` custom element and `format.turbo_stream` rendering remain available, which is what the per-view conversions in rollout steps 2–5 will rely on.
- ESM `import { Turbo } from "/assets/turbo.min.js"` (instead of `import * as Turbo`) matches the named export of `turbo-rails` 2.x (`turbo.min.js` ends with `export { Turbo, cable }`). `window.Turbo = Turbo` is set so future inline scripts and Stimulus controllers can reach the same instance without re-importing.

## [7.1.1] - 2026-05-05

### Fixed

- **Generated apps from 7.1.0 raised `ActionController::UnknownFormat` on every form POST** (e.g. creating an Apartment). 7.1.0 added `//= require turbo` to the Sprockets bundle (`app/assets/javascripts/inline_forms/inline_forms.js`), but `turbo-rails` 2.x ships only an ES-module build (`turbo.js` / `turbo.min.js` end with `export { Turbo, cable }`). Sprockets concatenates that ESM source into a single `<script>` payload, where the top-level `export` is a syntax error; the browser stops parsing the bundle at that point, jquery-ujs never binds its `data-remote` handler, and the form submits as a plain HTML POST. Inline_forms controllers (`InlineFormsController#create`, `#update`, etc.) only declare `format.js`, so the request raises `UnknownFormat`. Removed the `//= require turbo` line and the related runtime `Turbo.session.drive = false` initializer from the bundle, with a comment in `inline_forms.js` explaining why and pointing at the rollout step that will load Turbo properly (as a `<script type="module">`) once the first view is actually converted to a Turbo Frame / Stream.
- **Reverted `data-turbo-track => "reload"`** on the main `javascript_include_tag` in both layouts (`app/views/layouts/inline_forms.html.erb`, `app/views/layouts/application.html.erb`) since Turbo is not loaded in this slice and the attribute is meaningless without it. (The previous `data-turbolinks-track` was likewise meaningless; both are dropped.)

### Notes

- `gem 'turbo-rails'` remains in the installer Gemfile (added in 7.1.0). That alone is what the foundation slice of `stuff/ujs-to-turbo.md` requires: server-side **Mime type / view format registration** so controllers can later return `format.turbo_stream` and views can use `<turbo-frame>`. Loading Turbo's JS into the page is deferred to the next slice (the first frame/stream conversion), which will inject Turbo as a `<script type="module">` so it does not collide with the Sprockets bundle.

## [7.1.0] - 2026-05-05 [YANKED]

Broken release: `//= require turbo` in the Sprockets bundle introduced a syntax error that disabled jquery-ujs and caused `ActionController::UnknownFormat` on every form submission. Superseded by 7.1.1.

### Added

- **Hotwire / Turbo foundation in generated apps**: installer Gemfile (`bin/inline_forms_installer_core.rb`) now adds `gem 'turbo-rails'`, which registers the `turbo_stream` Mime type and view format so controllers can opt in to `format.turbo_stream` and `<turbo-frame>` responses going forward.

## [7.0.4] - 2026-05-05

### Changed

- **Pin CarrierWave in generated apps (`bin/inline_forms_installer_core.rb`)**: `gem 'carrierwave'` → `gem 'carrierwave', '~> 3.1'`. CarrierWave 3.1 (released Dec 2024, latest 3.1.2 from Apr 2025) supports Rails 6.0–8.0, matches the gem's existing local-disk uploader pattern, and locks generated apps out of a hypothetical 4.x with breaking changes. No code/API change for uploaders themselves.

### Added

- **README section "File uploads (CarrierWave)"** documenting the upload story (CarrierWave 3.1, local filesystem under `public/uploads/`, default uploader from `rails generate uploader`), pointing at `carrierwave-aws` / fog for S3, and noting that generated apps also pull in ActiveStorage transitively to back ActionText embeds (`:rich_text` form element) — image uploads still use CarrierWave; ActiveStorage is only there for ActionText.

## [7.0.3] - 2026-05-05

### Fixed

- **PaperTrail did not record ActionText (`rich_text`) edits.** `has_rich_text :foo` stores its body in the polymorphic `action_text_rich_texts` table, not on the parent model, so `has_paper_trail` on (e.g.) `Apartment` could never see body edits. Recommended by paper_trail's maintainer in [stackoverflow #55544935](https://stackoverflow.com/questions/55544935/how-to-get-paper-trail-to-work-with-action-text); also applies to PaperTrail >= 13 and Rails 7.

### Added

- **`config/initializers/rich_text_paper_trail.rb` in generated apps (`bin/inline_forms_installer_core.rb`)**: declares `has_paper_trail` on `ActionText::RichText` via `ActiveSupport.on_load(:action_text_rich_text)`, so each rich-text save creates a `PaperTrail::Version` row whose `item_type` is `ActionText::RichText`.
- **`InlineFormsHelper#inline_forms_versions_for(object)` (`app/helpers/inline_forms_helper.rb`)**: returns the parent model's PaperTrail versions merged with versions of every associated `ActionText::RichText` record, sorted by `created_at`. Each entry carries its `:kind` (`:primary` or `:rich_text`) and, for rich-text entries, the attribute name (e.g. `"description"`).
- **Versions panel now surfaces rich-text edits (`app/views/inline_forms/_versions_list.html.erb`)**: iterates `inline_forms_versions_for(@object)` instead of `@object.versions`, labels rich-text rows as `update (rich text)`, renders body diffs under the rich-text attribute name (so a `description` edit shows up as `description`, not `body`), and omits noise columns (`record_id`, `record_type`, `name`) from the rich-text changeset display. Restore links remain on the parent rows only (the existing revert path doesn't know how to roll back a rich-text version).
- **Regression test extension** in `test/models/example_app_paper_trail_changeset_test.rb`: updates an `Apartment#description` (a `rich_text`) and asserts `inline_forms_versions_for` returns a rich-text entry whose `body` changeset moves between the old and new HTML.

## [7.0.2] - 2026-05-05

### Fixed

- **PaperTrail `version.changeset` was always empty in generated apps** (long-standing bug, predates the 7.0.1 PaperTrail upgrade). The inline_forms versions panel (`app/views/inline_forms/_versions_list.html.erb`) iterates `version.changeset`; under Rails 7 + PaperTrail >= 13 (and the older `acesuares/paper_trail` v12 fork) that call routes through `YAML.safe_load` with `ActiveRecord.yaml_column_permitted_classes` as the allow-list. Rails 7's default is `[Symbol]`, so the very first attribute in any update's `object_changes` (`updated_at`, an `ActiveSupport::TimeWithZone`) raised `Psych::DisallowedClass`; PaperTrail rescued that and returned `{}`, so every row in the versions list rendered as **`empty`**.

### Added

- **`config/initializers/paper_trail_yaml_safe_load.rb` in generated apps (`bin/inline_forms_installer_core.rb`)**: extends `ActiveRecord.yaml_column_permitted_classes` (and the matching `Rails.application.config.active_record.yaml_column_permitted_classes`) with `Symbol, Date, Time, BigDecimal, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, ActiveSupport::HashWithIndifferentAccess`. With this in place, `version.changeset` round-trips and the inline versions panel shows real diffs for `update` events.
- **Regression test** `test/models/example_app_paper_trail_changeset_test.rb` (added to the `--example` test bundle): creates and updates an `Apartment`, then asserts `version.changeset` is non-empty and contains the expected old/new tuples. Runs under `bundle exec rails test` in any new example app and would have caught this bug.

## [7.0.1] - 2026-05-05

### Changed

- **Generated app Gemfile (`bin/inline_forms_installer_core.rb`)**: depend on the canonical `paper_trail` gem from RubyGems (`gem 'paper_trail', '~> 16.0'`) instead of the long-frozen `acesuares/paper_trail` git fork. PaperTrail 16 supports ActiveRecord `>= 6.1, < 8.1` and Ruby `>= 3.0`, which matches this gem's Rails 7.0 / Ruby 3.2 target. Removes the "not compatible with ActiveRecord 7.0" boot warning that PaperTrail 12 (the fork's base) emitted.
- **Installer paper_trail step (`bin/inline_forms_installer_core.rb`)**: drop the `--with-mysql` flag. That option only exists on the `acesuares` fork (it is the fork's sole behavioral patch on top of upstream PaperTrail) and is not recognized by upstream PaperTrail. The generator now runs `paper_trail:install --with-changes` for both sqlite and mysql apps; PaperTrail detects MySQL via the live ActiveRecord connection, which is fine because the installer documents creating the mysql development database before this step (sqlite needs no pre-existing DB).

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