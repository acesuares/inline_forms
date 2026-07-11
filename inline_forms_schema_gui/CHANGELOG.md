# Changelog

All notable changes to this gem are documented in this file. Versions are in
lockstep with inline_forms / inline_forms_installer / validation_hints.

## [Unreleased]

### Added

- **Batch pipeline (plan phases 1-3, and the tenant half of 4).**
  - Persisted intents: `InlineForms::SchemaBatch` + `InlineForms::SchemaIntentRecord`
    (`rails g inline_forms_schema_gui:install` writes the migration; the
    installer runs it for `--schema-gui` apps). Drafts accumulate in a
    batch (the "cart"); **submit freezes it** — intents and batch become
    immutable (model-enforced) and a content digest seals the intent list.
  - GUI: `/schema` index (draft cart, submit with optional apply window,
    batch history), "Add to batch" on preview. Direct apply stays dev-only;
    drafting in production requires the explicit
    `InlineFormsSchemaGui.production_drafting = true` opt-in (default off).
  - Machine endpoints for the CI loop, token-authenticated
    (`InlineFormsSchemaGui.export_token` / `INLINE_FORMS_SCHEMA_EXPORT_TOKEN`;
    404 when unconfigured): `GET /schema/batches/:id/export.json`,
    `POST /schema/batches/:id/status`.
  - Export/import/replay: `rake schema_gui:export_batch[id]`,
    `rake schema_gui:apply_batch[file]` (verifies the digest, re-validates
    every intent against the current checkout, replays through
    `SchemaApply#generate!` — codegen only, never migrates or commits),
    `rake schema_gui:mark_batch[id,status]`.
  - Deploy window (phase 4, tenant side): `rake schema_gui:apply_due`
    migrates ready batches whose window arrived, marks them applied, runs
    the optional `InlineFormsSchemaGui.restart_command`. A commented
    Forgejo Actions example ships in `doc/schema-apply-workflow.yml.example`
    (copied to the app's `doc/` by the install generator).
  - Routes are now drawn by `InlineFormsSchemaGui.draw_routes(self)` (one
    line in the app's routes.rb) so gem upgrades can add routes without
    editing the app.

- Initial extraction of the schema-change GUI out of the inline_forms engine
  into this separate mountable engine gem (phase 0 of
  `stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md`):
  `InlineForms::SchemaController`, its views and the `inline_forms_schema`
  layout. The staging services (`SchemaIntent`, `SchemaPreview`,
  `SchemaApply`, `SchemaLabel`) stay in inline_forms. Apps opt in via
  `inline_forms create --schema-gui` (implied by `--example`).
