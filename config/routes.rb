# typed: false
# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

# rubocop:disable Metrics/BlockLength
Serveme::Application.routes.draw do
  get "/404", to: "pages#not_found"
  get "/500", to: "pages#error"

  devise_for :users, controllers: { omniauth_callbacks: "sessions" }

  devise_scope :user do
    get "/sessions/auth/:provider", to: "sessions#passthru"
    get "/sessions/new", to: "sessions#new"
    post "/users/auth/:provider/callback", to: "sessions#steam"
    get "/users/auth/:provider/callback", to: "sessions#steam"
    delete "/users/logout", to: "devise/sessions#destroy"
  end

  resources :sessions do
    collection do
      get :steam
      post :passthru
      get :failure
    end
  end

  resources :users do
    collection do
      get :edit
      post :update
    end
    resources :reservations, only: :index
  end

  resources :reservations do
    member do
      post :extend_reservation, as: :extend
      get :status,              as: :status
      get :streaming,           as: :streaming
      get :rcon,                as: :rcon
      get :motd,                as: :motd
      patch :rcon_command, as: :rcon_command
      patch :motd_rcon_command, as: :motd_rcon_command
      get :stac_log, as: :stac_log
      post :prepare_zip
    end
    collection do
      post :find_servers_for_user
      patch :find_servers_for_reservation
      post :time_selection
      post :i_am_feeling_lucky
    end
    resources :log_uploads, only: %i[new create index] do
      collection do
        get :show_log
      end
    end
  end

  resources :map_uploads, only: %i[new create destroy] do
    collection do
      post :presigned_url
      post :complete
    end
  end
  resources :file_uploads, only: %i[new create show]
  resources :uploads, only: %i[show]

  get "league-request", to: "league_requests#new"
  post "league-request", to: "league_requests#create"

  resources :pages do
    collection do
      get :credits
      get :recent_reservations
      get :statistics
      get :server_providers
      get :faq
      get :ai
    end
  end

  resources :donators do
    collection do
      get :leaderboard
      post :lookup_user
    end
  end

  resources :stac_logs, only: %i[index]

  resources :server_configs, except: %i[show destroy]
  resources :whitelists, except: %i[show destroy]
  resources :server_notifications, except: [ :show, :new ]

  resources :player_statistics, only: :index
  resources :server_statistics, only: :index

  resources :private_servers, only: :create

  resources :servers, except: :destroy do
    member do
      post :force_update, as: :force_update
      post :restart, as: :restart
      get :sdr
    end
  end

  resources :orders, only: %i[new create index] do
    collection do
      get :redirect
      post :stripe
      post :create_payment_intent
      post :confirm_payment
      get :stripe_return
      get :status
    end
  end

  resources :vouchers

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web, at: "/sidekiq"
  end

  namespace :api do
    resources :users, only: :show
    resources :league_requests, only: :index
    resources :maps, only: :index
    resources :servers, only: :index
    resources :donators, except: %i[edit update index]
    resources :reservations do
      member do
        post :extend
      end
      collection do
        post :find_servers
      end
    end
  end

  # Serve swagger YAML dynamically with current server first (before rswag engine)
  get "/api-docs/v1/swagger.yaml", to: "api_docs#swagger_spec"

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Stripe webhook
  post "/stripe/webhook", to: "stripe_webhooks#create"

  # Pretty URL
  get   "/donate",                        to: "orders#new",                as: "donate"
  get   "/voucher(/:code)",               to: "vouchers#new",              as: "claim"
  get   "/statistics",                    to: "pages#statistics",          as: "statistics"
  get   "/stats",                         to: "pages#stats",               as: "stats"
  get   "/faq",                           to: "pages#faq",                 as: "faq"
  get   "/credits",                       to: "pages#credits",             as: "credits"
  get   "/server-providers",              to: "pages#server_providers",    as: "server_providers"
  get   "/no-to-war",                     to: "pages#no_to_war",           as: "no_to_war"
  post  "/no-to-war",                     to: "pages#no_vatnik",           as: "no_vatnik"
  get   "/your-reservations",             to: "reservations#index",        as: "your_reservations"
  get   "/reservations-played",           to: "reservations#played_in",    as: "played_in"
  get   "/recent-reservations",           to: "pages#recent_reservations", as: "recent_reservations"
  get   "/settings",                      to: "users#edit",                as: "settings"
  get   "/upload-map",                    to: "map_uploads#new",           as: "upload_map"
  get   "/upload-file",                   to: "file_uploads#new",          as: "upload_file"
  get   "/maps",                          to: "map_uploads#index",         as: "maps"
  get   "/maps/:sort_by",                 to: "map_uploads#index",         as: "maps_sorted"
  get   "/private-servers",               to: "pages#private_servers",     as: "private_server_info"
  get   "/pings",                         to: "pings#index",               as: "pings"
  get   "/players",                       to: "players#index",             as: "players"
  get   "/server-monitoring",             to: "server_monitoring#index",   as: "server_monitoring"
  post  "/server-monitoring/poll",        to: "server_monitoring#poll",    as: "poll_server_monitoring"

  get   "/player_statistics/sdr",                                          to: "player_statistics#show_for_sdr",                     as: "show_sdr"
  get   "/player_statistics/reservation/:reservation_id",                  to: "player_statistics#show_for_reservation",             as: "show_reservation_statistic"
  get   "/player_statistics/steam/:steam_uid",                             to: "player_statistics#show_for_player",                  as: "show_player_statistic"
  get   "/player_statistics/ip/:ip",                                       to: "player_statistics#show_for_ip",                      as: "show_ip_statistic"
  get   "/player_statistics/reservation/:reservation_id/steam/:steam_uid", to: "player_statistics#show_for_reservation_and_player",  as: "show_reservation_and_player_statistic"
  get   "/player_statistics/server/:server_id",                            to: "player_statistics#show_for_server",                  as: "show_server_player_statistic"
  get   "/player_statistics/server-ip/:server_id",                         to: "player_statistics#show_for_server_ip",               as: "show_server_ip_player_statistic"

  get   "/server_statistics/server/:server_id",                            to: "server_statistics#show_for_server",                  as: "show_server_statistic"
  get   "/server_statistics/reservation/:reservation_id",                  to: "server_statistics#show_for_reservation",             as: "show_reservation_server_statistic"

  get   "/login",                         to: "sessions#new", as: :login
  get   "/users/auth/failure",            to: "sessions#failure"
  post  "/users/auth/failure",            to: "sessions#failure"

  get "/rcon-autocomplete/:id", to: "reservations#rcon_autocomplete", as: "rcon_autocomplete"

  get "sdr", to: "sdr#index"

  root to: "pages#welcome"
  match "*path", via: :all, to: "pages#not_found" unless Rails.env.test?
end
# rubocop:enable Metrics/BlockLength
