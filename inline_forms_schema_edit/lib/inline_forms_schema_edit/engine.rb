# -*- encoding : utf-8 -*-

module InlineFormsSchemaEdit
  # Deliberately NOT `isolate_namespace`: the gem contributes
  # `InlineForms::SchemaController` (+ its views and layout) into the host
  # app, in the same namespace the inline_forms engine uses, so the routes
  # the installer writes (`inline_forms/schema#new` etc.) and the staging
  # services in inline_forms (`SchemaIntent`/`SchemaPreview`/`SchemaApply`/
  # `SchemaLabel`) resolve exactly as they did when the controller lived in
  # the engine itself.
  class Engine < Rails::Engine
  end
end
