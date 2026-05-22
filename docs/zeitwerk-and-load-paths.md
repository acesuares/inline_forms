# Zeitwerk and load paths (inline_forms + validation_hints)

**Last verified:** 2026-05-22 — `bundle exec rails zeitwerk:check` on a fresh **`inline_forms create MyApp -d sqlite --example`** app (Rails **8.0.5**): **All is good!**

## inline_forms engine

### Autoloaded by Zeitwerk (host app eager load)

Under the engine’s `app/` tree:

- `app/controllers/` — `InlineFormsController`, concerns
- `app/helpers/inline_forms_helper.rb`
- `app/models/concerns/inline_forms/soft_deletable.rb`
- `app/validators/*` — custom validators

### Intentionally **not** Zeitwerk-autoloaded

| Path | Mechanism | Why |
|------|-----------|-----|
| `lib/inline_forms/form_elements/*_helper.rb` | `Rails.autoloaders.main.ignore` + `FormElements.load_helpers!` (`Dir[]` + `require`) | Historical top-level helper method names (`text_field_show`, …); `_helper.rb` filenames do not map to Zeitwerk constants |
| `lib/inline_forms.rb` boot | Explicit `require` of version, registry, `form_elements`, `turbo_tabs_builder`, `archived_form_elements` | Boot order before engine initializers |
| `lib/generators/` | Rails generator autoload | Not part of host app Zeitwerk |
| `archived/form_elements/` | Not required | Legacy project-specific elements; registry blocks use in `inline_forms_attribute_list` |

Track B migration (7.13.x): moved active elements from `app/helpers/form_elements/*.rb` to `lib/inline_forms/form_elements/*_helper.rb`. See `CHANGELOG.md` (Zeitwerk / form elements).

### Nothing left on the old path

There is **no** `app/helpers/form_elements/` in the shipped gem (only under `archived/`).

## validation_hints

| Path | Mechanism | Why |
|------|-----------|-----|
| `lib/active_model/hints.rb` | Explicit `require` in `lib/validation_hints.rb` | Defines `ActiveModel::Hints` in the `ActiveModel` namespace (collapse); not under `validation_hints/` |
| `lib/validation_hints/validations_patch.rb` | Explicit `require` | Patches applied via `ActiveSupport.on_load(:active_model)` |
| `lib/validation_hints/railtie.rb` | Loaded when `Rails::Railtie` is defined | Standard gem entry |

Non-Rails use: `require "validation_hints"` loads hints + patch + I18n without Zeitwerk.

## Host app checklist

After upgrading or generating an app:

```bash
cd MyApp && rvm use . && bundle exec rails zeitwerk:check
```

If you vendor custom form-element helpers into the host app, keep them under `app/helpers/` with Zeitwerk-friendly names or add `config.autoload_lib` / ignores as needed.
