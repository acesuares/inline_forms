# frozen_string_literal: true

# Mirrors the routes `rails g inline_forms` injects for each resource.
Rails.application.routes.draw do
  resources :widgets do
    post "revert", on: :member
    get "list_versions", on: :member
  end
end
