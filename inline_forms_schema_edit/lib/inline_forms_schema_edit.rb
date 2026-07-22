# -*- encoding : utf-8 -*-

require "inline_forms_schema_edit/version"
require "inline_forms_schema_edit/engine" if defined?(Rails::Engine)
require "inline_forms_schema_edit/intent_validator"
require "inline_forms_schema_edit/batch_export"
require "inline_forms_schema_edit/batch_import"

# InlineFormsSchemaEdit packages the schema-change GUI (add a field to a model
# through the browser) as a mountable engine, separate from the inline_forms
# runtime engine. Apps opt in at creation time (`inline_forms create
# --schema-edit`, implied by `--example`); apps that never change their own
# schema ship without this surface entirely.
#
# The GUI is the web layer plus the batch pipeline (persisted intents,
# freeze-on-submit, export/import/replay). The codegen machinery it drives
# lives in inline_forms: SchemaIntent (the proposed change), SchemaPreview
# (cheap subclass + virtual-attribute preview), SchemaApply (runs the
# inline_forms_addto generator; never db:migrate) and SchemaLabel (locale
# label writing). See stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md.
module InlineFormsSchemaEdit
  # Production posture. By default the whole GUI stays non-production (the
  # phase-0 behavior: authoring happens on a dev checkout). A SaaS tenant app
  # that drafts intents in production opts in explicitly:
  #
  #   InlineFormsSchemaEdit.production_drafting = true
  #
  # Even then, only DRAFTING (new/preview/draft/index/submit) is allowed in
  # production; direct apply (codegen into the running app's tree) is never
  # available there — production never writes code.
  mattr_accessor :production_drafting
  self.production_drafting = false

  # Shared-secret token for the machine endpoints (batch export + status
  # callback) used by the CI pipeline. Both endpoints 404 unless a token is
  # configured — secure by default. Also settable via ENV.
  mattr_writer :export_token
  def self.export_token
    @@export_token.presence || ENV["INLINE_FORMS_SCHEMA_EXPORT_TOKEN"].presence
  end
  self.export_token = nil

  # Optional command run by `rake schema_edit:apply_due` after migrating a due
  # batch (e.g. "touch tmp/restart.txt" for Passenger, or a systemd restart).
  # nil = no restart is attempted; the deploy tooling owns it.
  mattr_accessor :restart_command
  self.restart_command = nil

  # All GUI + pipeline routes, drawn from one place so gem upgrades can add
  # routes without editing the app's routes.rb. The installer writes a single
  # line into generated apps:
  #
  #   InlineFormsSchemaEdit.draw_routes(self)
  #
  # (Route names are kept identical to the phase-0 literal routes.)
  def self.draw_routes(router)
    router.get    "schema",         to: "inline_forms/schema#index",   as: :inline_forms_schema_index
    router.get    "schema/new",     to: "inline_forms/schema#new",     as: :inline_forms_schema_new
    router.post   "schema/preview", to: "inline_forms/schema#preview", as: :inline_forms_schema_preview
    router.post   "schema",         to: "inline_forms/schema#create",  as: :inline_forms_schema
    router.post   "schema/draft",   to: "inline_forms/schema#draft",   as: :inline_forms_schema_draft
    router.delete "schema/draft/:id", to: "inline_forms/schema#remove_draft", as: :inline_forms_schema_remove_draft
    router.post   "schema/batch/submit", to: "inline_forms/schema#submit_batch", as: :inline_forms_schema_submit_batch
    router.get    "schema/batches/:id/export", to: "inline_forms/schema#export",
                  defaults: { format: :json }, as: :inline_forms_schema_export
    router.post   "schema/batches/:id/status", to: "inline_forms/schema#batch_status",
                  as: :inline_forms_schema_batch_status
  end
end
