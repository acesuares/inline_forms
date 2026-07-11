# frozen_string_literal: true

# Mirrors the routes `rails g inline_forms` injects for each resource.
Rails.application.routes.draw do
  # Devise stand-in: the inline_forms header links destroy_user_session_path.
  delete "logout", to: proc { [ 204, {}, [] ] }, as: :destroy_user_session

  resources :widgets do
    post "revert", on: :member
    get "list_versions", on: :member
  end

  resources :machines do
    post "revert", on: :member
    get "list_versions", on: :member
  end

  resources :parts do
    post "revert", on: :member
    get "list_versions", on: :member
  end

  resources :gizmos do
    post "revert", on: :member
    get "list_versions", on: :member
  end

  # Schema-change GUI (example-app-only in real installs; routed here for the
  # engine's fast test suite). See InlineForms::SchemaController.
  get  "schema/new",     to: "inline_forms/schema#new",     as: :inline_forms_schema_new
  post "schema/preview", to: "inline_forms/schema#preview", as: :inline_forms_schema_preview
  post "schema",         to: "inline_forms/schema#create",  as: :inline_forms_schema
end
