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

Programmatic registry: `InlineForms::ARCHIVED_FORM_ELEMENTS` in `lib/inline_forms.rb` (boot-time check if a model still declares an archived symbol).

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

## Adding a new archive entry

When retiring a form element:

1. Move its helper, and any dedicated model/controller/views, into `archived/form_elements/<name>/app/…`.
2. Add `archived/form_elements/<name>/README.md` with dependencies, routes, Turbo/UJS status, and restore steps.
3. Register it in `InlineForms::ARCHIVED_FORM_ELEMENTS`.
4. Document in CHANGELOG under **Removed** or **Changed**.
5. Update `docs/ujs-to-turbo.md` if the element had migration checklist items.
