# -*- encoding : utf-8 -*-

require "inline_forms_schema_gui/version"
require "inline_forms_schema_gui/engine" if defined?(Rails::Engine)

# InlineFormsSchemaGui packages the schema-change GUI (add a field to a model
# through the browser) as a mountable engine, separate from the inline_forms
# runtime engine. Apps opt in at creation time (`inline_forms create
# --schema-gui`, implied by `--example`); apps that never change their own
# schema ship without this surface entirely.
#
# The GUI is the web layer only. The machinery it drives lives in
# inline_forms: SchemaIntent (the proposed change), SchemaPreview (cheap
# subclass + virtual-attribute preview), SchemaApply (runs the
# inline_forms_addto generator; never db:migrate) and SchemaLabel (locale
# label writing). See stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md.
module InlineFormsSchemaGui
end
