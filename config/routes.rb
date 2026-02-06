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
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations"
  }

  # Demo Calendar (public, session-based)
  namespace :demo do
    root to: "calendars#show"
    get :events, to: "calendars#events"
    resources :events, only: [:create, :destroy]
    resource :calendar, only: [:show] do
      post :persist
    end
  end

  # Root - Demo Calendar
  root to: "demo/calendars#show"

  # Timeline (posts)
  get "timeline", to: "posts#index", as: :timeline

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
  resources :calendar, only: [:index, :show, :create, :edit, :update] do
    collection do
      get :events
    end
    member do
      post :generate_ical_token
    end

    # Nested scraper management
    resources :scraper_sources, only: [:create, :update, :destroy] do
      member do
        post :run
      end
    end

    # iCal import
    resource :import, only: [:update], controller: "calendars/imports" do
      post :sync
    end
  end

  # iCal feed (public, token-based access)
  get "calendars/:ical_token.ics", to: "calendars/ical#show", as: :calendar_ical_feed, format: :ics

  # External calendar connections
  resources :google_calendars, only: [:index, :create, :destroy] do
    member do
      post :refresh
    end
  end
  resources :calendar_connections, only: [:index, :create]

  # User profiles
  get "profile", to: "users#profile", as: :profile
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
        member do
          get :ics
        end
      end
      resources :calendars, only: [:index, :show]
      resource :api_token, only: [:create, :destroy]
      post :chat, to: "chat#create"
    end
  end
end
