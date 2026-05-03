# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

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