Rails.application.routes.draw do
  # Auth
  get    "signup", to: "registrations#new",  as: :signup
  post   "signup", to: "registrations#create"
  get    "login",  to: "sessions#new",       as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",   as: :logout

  resource :password_reset, only: %i[new create edit update]

  get "up" => "rails/health#show", as: :rails_health_check

  # Google Calendar OAuth
  namespace :google do
    get  "oauth/authorize", to: "oauth#authorize", as: :oauth_authorize
    get  "oauth/callback",  to: "oauth#callback",  as: :oauth_callback
    delete "oauth",         to: "oauth#destroy",   as: :oauth_disconnect
  end

  get "privacy", to: "pages#privacy"
  get "about",   to: "pages#about"
  get "terms",   to: "pages#terms"

  get "manifest", to: "pwa#manifest", defaults: { format: :json }
  get "offline",  to: "pwa#offline"

  get "dashboard",     to: "dashboard#index"
  get "dashboard/timeline", to: "dashboard#timeline", as: :timeline

  resource :settings, only: %i[edit update]
  patch "/settings/change_password", to: "settings#change_password", as: :change_password_settings
  delete "/account", to: "registrations#destroy", as: :delete_account

  # AI-negotiated meeting matchmaking
  resources :matches, only: %i[index show], controller: "meeting_proposals"
  post "matchmaking/run", to: "matchmaking#create", as: :run_matchmaking

  resources :people do
    resources :person_facts, only: %i[show edit create update destroy] do
      collection { post :extract }
    end
    collection do
      match :import, via: %i[get post]
      get :export
    end
    member do
      patch :snooze
      patch :toggle_favorite
      patch :toggle_tag
      get :notes_edit
    end
  end
  resources :events
  resources :tags,   only: %i[index update destroy]
  resources :blocks, only: %i[create destroy]

  root "dashboard#index"
end
