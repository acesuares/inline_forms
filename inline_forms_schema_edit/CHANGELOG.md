# Changelog

All notable changes to this gem are documented in this file. Versions are in
lockstep with inline_forms / inline_forms_installer / validation_hints.

## [Unreleased]

## [8.1.44] - 2026-07-24

### Changed

- Version bump to stay in lockstep with `inline_forms` /
  `inline_forms_installer` / `validation_hints` 8.1.44 (`simple_file_field`
  download-link fix). No changes to this gem's own code.

## [8.1.43] - 2026-07-22

### Changed

- Version bump to stay in lockstep with `inline_forms` /
  `inline_forms_installer` / `validation_hints` 8.1.43 (schema-GUI line merged
  into master alongside the picker fix). No changes to this gem's own code.

## [8.1.42] - 2026-07-22

### Changed

- Version bump to stay in lockstep with `inline_forms` /
  `inline_forms_installer` / `validation_hints` 8.1.42. This gem packages its
  own files (`{app,doc,lib}` glob) and was unaffected by the `stuff/`
  gem-build leak fixed in the main gem.

### Added

- **Batch pipeline (plan phases 1-3, and the tenant half of 4).**
  - Persisted intents: `InlineForms::SchemaBatch` + `InlineForms::SchemaIntentRecord`
    (`rails g inline_forms_schema_edit:install` writes the migration; the
    installer runs it for `--schema-edit` apps). Drafts accumulate in a
    batch (the "cart"); **submit freezes it** — intents and batch become
    immutable (model-enforced) and a content digest seals the intent list.
  - GUI: `/schema` index (draft cart, submit with optional apply window,
    batch history), "Add to batch" on preview. Direct apply stays dev-only;
    drafting in production requires the explicit
    `InlineFormsSchemaEdit.production_drafting = true` opt-in (default off).
  - Machine endpoints for the CI loop, token-authenticated
    (`InlineFormsSchemaEdit.export_token` / `INLINE_FORMS_SCHEMA_EXPORT_TOKEN`;
    404 when unconfigured): `GET /schema/batches/:id/export.json`,
    `POST /schema/batches/:id/status`.
  - Export/import/replay: `rake schema_edit:export_batch[id]`,
    `rake schema_edit:apply_batch[file]` (verifies the digest, re-validates
    every intent against the current checkout, replays through
    `SchemaApply#generate!` — codegen only, never migrates or commits),
    `rake schema_edit:mark_batch[id,status]`.
  - Deploy window (phase 4, tenant side): `rake schema_edit:apply_due`
    migrates ready batches whose window arrived, marks them applied, runs
    the optional `InlineFormsSchemaEdit.restart_command`. A commented
    Forgejo Actions example ships in `doc/schema-apply-workflow.yml.example`
    (copied to the app's `doc/` by the install generator).
  - Routes are now drawn by `InlineFormsSchemaEdit.draw_routes(self)` (one
    line in the app's routes.rb) so gem upgrades can add routes without
    editing the app.

- Initial extraction of the schema-change GUI out of the inline_forms engine
  into this separate mountable engine gem (phase 0 of
  `stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md`):
  `InlineForms::SchemaController`, its views and the `inline_forms_schema`
  layout. The staging services (`SchemaIntent`, `SchemaPreview`,
  `SchemaApply`, `SchemaLabel`) stay in inline_forms. Apps opt in via
  `inline_forms create --schema-edit` (implied by `--example`).
