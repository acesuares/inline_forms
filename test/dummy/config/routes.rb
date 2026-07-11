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
end
