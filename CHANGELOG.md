# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [6.3.3] - 2026-05-03

### Added

- **`--example` installs regression tests** under `test/example_app/` and `test/integration/example_app_*_test.rb`, plus model coverage for the generated Photo/Apartment resources. Run them with **`bundle exec rails test`** in the new app.

### Changed

- **Example installer** no longer runs **`bundle exec rails s`** at the end (it blocked the shell). Start the server manually when you want to use the browser.

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