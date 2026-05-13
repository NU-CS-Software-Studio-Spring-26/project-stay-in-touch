Rails.application.routes.draw do
  # Auth
  get    "signup", to: "registrations#new",  as: :signup
  post   "signup", to: "registrations#create"
  get    "login",  to: "sessions#new",       as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy",   as: :logout

  get "up" => "rails/health#show", as: :rails_health_check

  # Google Calendar OAuth
  namespace :google do
    get  "oauth/authorize", to: "oauth#authorize", as: :oauth_authorize
    get  "oauth/callback",  to: "oauth#callback",  as: :oauth_callback
    delete "oauth",         to: "oauth#destroy",   as: :oauth_disconnect
  end

  get "privacy", to: "pages#privacy"
  get "about",   to: "pages#about"

  get "manifest", to: "pwa#manifest", defaults: { format: :json }
  get "offline",  to: "pwa#offline"

  resource  :settings, only: %i[edit update]
  resources :people
  resources :events

  root "people#index"
end
