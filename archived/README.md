# Archived and removed features

This directory is the **versioned archive** for inline_forms capabilities that are no longer loaded by default but may be restored if requirements change.

## Catalog

| Symbol / feature | Status | Gem version | Location / notes |
|------------------|--------|-------------|------------------|
| `:geo_code_curacao` | **Archived** | **7.6.0** | [`form_elements/geo_code_curacao/`](form_elements/geo_code_curacao/) |
| `:chicas_photo_list`, `:chicas_family_photo_list`, `:chicas_dropdown_with_family_members` | **Archived** | **7.6.0** | [`form_elements/chicas/`](form_elements/chicas/) |
| `:kansen_slider` | **Archived** | **7.6.0** | [`form_elements/kansen_slider/`](form_elements/kansen_slider/) |
| `:tree`, `:move` | **Archived** | **7.7.0** | [`form_elements/tree/`](form_elements/tree/) — host `#children`, `#hash_tree_to_collection`, `#add_child` |
| `:absence_list` | **Removed** (source not in repo) | **6.3.0** | See [CHANGELOG](../CHANGELOG.md#630---2026-05-03); vendor from git history or app copy |
| `:ckeditor`, `:text_area_without_ckeditor` | **Archived** | **8.1.21** | [`form_elements/ckeditor/`](form_elements/ckeditor/) — use `:rich_text` or `:plain_text` / `:plain_text_area` |
| `:question_list` | **Archived** | **8.1.30** | [`form_elements/question_list/`](form_elements/question_list/) — hardcoded host `Question` model |
| `:dnsrecords` | **Archived** | **8.1.30** | [`form_elements/dns_records/`](form_elements/dns_records/) — host `a_records`/`djbdns_line` APIs |

Programmatic registry: `InlineForms::ARCHIVED_FORM_ELEMENTS` in `lib/inline_forms.rb` (checked on every code reload in development, after the app's own `to_prepare` blocks, if a model still declares an archived symbol; since 8.1.85 not at boot).

## Layout

```
archived/
  README.md                 ← this file
  form_elements/
    README.md               ← how form-element archives work
    <name>/
      README.md             ← restore steps for that element
      app/                  ← mirror of engine paths under app/
```

Active form elements load from `app/helpers/form_elements/*.rb` only (top-level `*.rb` in that folder). Anything under `archived/` is **not** required automatically.

## Restoring an archived form element

1. Read `archived/form_elements/<name>/README.md`.
2. Copy files from `archived/form_elements/<name>/app/` back into the gem’s `app/` tree (same relative paths).
3. Re-add routes, DB tables, and assets described in that README.
4. Remove the symbol from `InlineForms::ARCHIVED_FORM_ELEMENTS` (or leave it and remove the model reference only in your app).
5. Bump your app/gem as needed; run tests.

## Vendoring an archived form element into an app

An app can keep using an archived element without changing the gem: put its
helper methods (`<name>_show`, `<name>_edit`, `<name>_update`, and `_info` if it
has one) in a module, plus the models, controllers, views, routes and assets
its README lists. The views call `_show` and `_edit`, but the save calls
`_update` on the controller, which does not get the app's helpers. So include
the module into both, in a `to_prepare` (both are reloadable engine
constants). Make its methods **private**: a public method of a module
included into a controller is an action, and since 8.1.83 the engine's own
form element helpers are not.

```ruby
# lib/form_elements/geo_code_curacao.rb
module GeoCodeCuracaoHelper
  private

  def geo_code_curacao_show(object, attribute) = …
  def geo_code_curacao_edit(object, attribute) = …
  def geo_code_curacao_update(object, attribute) = …
end

# config/initializers/inline_forms_vendored_form_elements.rb
require Rails.root.join("lib/form_elements/geo_code_curacao").to_s

Rails.application.config.to_prepare do
  [InlineFormsHelper, InlineFormsController].each { |target| target.include(GeoCodeCuracaoHelper) }
end
```

A module only under `app/helpers/` shows and edits, but every save is refused
(400). Since 8.1.81 the archived-element check
(`InlineForms.validate_no_archived_form_elements_for!`) skips an archived
symbol when the app's helpers (`ApplicationController.helpers`) answer
`<name>_show`, private or not (8.1.84), so the element is then the app's.
Since 8.1.85 that check runs on each code reload in development, after the
app's own `to_prepare` blocks, so the include above is seen; it no longer
runs at boot. The archived files are
written in the old top-level `def` style; wrap them in a helper module
(`module GeoCodeCuracaoHelper … end`) and replace any jQuery/UJS they use.

## Adding a new archive entry

When retiring a form element:

1. Move its helper, and any dedicated model/controller/views, into `archived/form_elements/<name>/app/…`.
2. Add `archived/form_elements/<name>/README.md` with dependencies, routes, Turbo/UJS status, and restore steps.
3. Register it in `InlineForms::ARCHIVED_FORM_ELEMENTS`.
4. Document in CHANGELOG under **Removed** or **Changed**.
5. Update `docs/ujs-to-turbo.md` if the element had migration checklist items.
