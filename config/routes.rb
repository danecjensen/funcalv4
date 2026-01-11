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

  # Event RSVPs
  resources :events, only: [:show] do
    resource :rsvp, controller: "event_rsvps", only: [:create, :destroy]
  end

  # Calendar
  resources :calendar, only: [:index, :show, :create] do
    collection do
      get :events
    end
    member do
      post :generate_ical_token
    end
  end

  # iCal feed (public, token-based access)
  get "calendars/:ical_token.ics", to: "calendars/ical#show", as: :calendar_ical_feed, format: :ics

  # User profiles
  resources :users, only: [:show, :edit, :update]

  # Existing
  resources :notifications, only: [:index]
  resources :announcements, only: [:index]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes for Chrome extension and MCP server
  namespace :api do
    namespace :v1 do
      resources :events, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :search
        end
      end
      resources :calendars, only: [:index, :show]
      post :chat, to: "chat#create"
    end
  end
end
