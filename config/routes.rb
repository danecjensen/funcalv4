require 'sidekiq/web'

Rails.application.routes.draw do
authenticate :user, lambda { |u| u.admin? } do
  mount Sidekiq::Web => '/sidekiq'

  namespace :madmin do
    resources :impersonates do
      post :impersonate, on: :member
      post :stop_impersonating, on: :collection
    end
  end
end

  # Authentication
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Timeline (root)
  root to: "posts#index"

  # Posts with nested comments and likes
  resources :posts do
    resources :comments, only: [:create, :destroy]
    resource :like, only: [:create, :destroy]
  end

  # Calendar
  resources :calendar, only: [:index, :show] do
    collection do
      get :events
    end
  end

  # User profiles
  resources :users, only: [:show, :edit, :update]

  # Existing
  resources :notifications, only: [:index]
  resources :announcements, only: [:index]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes for Chrome extension
  namespace :api do
    namespace :v1 do
      resources :events, only: [:create, :index]
    end
  end
end
