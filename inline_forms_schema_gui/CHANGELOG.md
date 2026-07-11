# Changelog

All notable changes to this gem are documented in this file. Versions are in
lockstep with inline_forms / inline_forms_installer / validation_hints.

## [Unreleased]

### Added

- Initial extraction of the schema-change GUI out of the inline_forms engine
  into this separate mountable engine gem (phase 0 of
  `stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md`):
  `InlineForms::SchemaController`, its views and the `inline_forms_schema`
  layout. The staging services (`SchemaIntent`, `SchemaPreview`,
  `SchemaApply`, `SchemaLabel`) stay in inline_forms. Apps opt in via
  `inline_forms create --schema-gui` (implied by `--example`).
