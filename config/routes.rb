# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq/cron/web'

Serveme::Application.routes.draw do
  get '/404', to: 'pages#not_found'
  get '/500', to: 'pages#error'

  devise_for :users, controllers: { omniauth_callbacks: 'sessions' }

  devise_scope :user do
    get '/sessions/auth/:provider', to: 'sessions#passthru'
    get '/sessions/new', to: 'sessions#new'
    post '/users/auth/:provider/callback', to: 'sessions#steam'
    get '/users/auth/:provider/callback', to: 'sessions#steam'
    delete '/users/logout', to: 'devise/sessions#destroy'
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
  end

  resources :reservations do
    member do
      post :extend_reservation, as: :extend
      get :status,              as: :status
      get :streaming,           as: :streaming
      get :rcon,                as: :rcon
      patch :rcon_command, as: :rcon_command
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

  resources :map_uploads, only: %i[new create]
  resources :file_uploads, only: %i[new create show]

  get 'league-request', to: 'league_requests#new'
  post 'league-request', to: 'league_requests#create'

  resources :pages do
    collection do
      get :credits
      get :recent_reservations
      get :statistics
      get :server_providers
      get :faq
    end
  end

  resources :donators do
    collection do
      get :leaderboard
    end
  end

  resources :player_statistics, only: :index
  resources :server_statistics, only: :index

  resources :private_servers, only: :create

  resources :servers, only: :index

  resources :orders, only: %i[new create index] do
    collection do
      get :redirect
      post :stripe
    end
  end

  resources :vouchers

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web, at: '/sidekiq'
  end

  namespace :api do
    resources :users, only: :show
    resources :maps, only: :index
    resources :servers, only: :index
    resources :donators, except: %i[edit update]
    resources :reservations do
      member do
        post :idle_reset
        post :extend
      end
      collection do
        post :find_servers
      end
    end
  end

  # Pretty URLs
  get   '/donate',                        to: 'orders#new',                as: 'donate'
  get   '/voucher(/:code)',               to: 'vouchers#new',              as: 'claim'
  get   '/statistics',                    to: 'pages#statistics',          as: 'statistics'
  get   '/stats',                         to: 'pages#stats',               as: 'stats'
  get   '/faq',                           to: 'pages#faq',                 as: 'faq'
  get   '/credits',                       to: 'pages#credits',             as: 'credits'
  get   '/server-providers',              to: 'pages#server_providers',    as: 'server_providers'
  get   '/your-reservations',             to: 'reservations#index',        as: 'your_reservations'
  get   '/reservations-played',           to: 'reservations#played_in',    as: 'played_in'
  get   '/recent-reservations',           to: 'pages#recent_reservations', as: 'recent_reservations'
  get   '/settings',                      to: 'users#edit',                as: 'settings'
  get   '/upload-map',                    to: 'map_uploads#new',           as: 'upload_map'
  get   '/upload-file',                   to: 'file_uploads#new',          as: 'upload_file'
  get   '/private-servers',               to: 'pages#private_servers',     as: 'private_server_info'

  get   '/player_statistics/reservation/:reservation_id',                  to: 'player_statistics#show_for_reservation',             as: 'show_reservation_statistic'
  get   '/player_statistics/steam/:steam_uid',                             to: 'player_statistics#show_for_player',                  as: 'show_player_statistic'
  get   '/player_statistics/ip/:ip',                                       to: 'player_statistics#show_for_ip',                      as: 'show_ip_statistic'
  get   '/player_statistics/reservation/:reservation_id/steam/:steam_uid', to: 'player_statistics#show_for_reservation_and_player',  as: 'show_reservation_and_player_statistic'
  get   '/player_statistics/server/:server_id',                            to: 'player_statistics#show_for_server',                  as: 'show_server_player_statistic'
  get   '/player_statistics/server-ip/:server_id',                         to: 'player_statistics#show_for_server_ip',               as: 'show_server_ip_player_statistic'

  get   '/server_statistics/server/:server_id',                            to: 'server_statistics#show_for_server',                  as: 'show_server_statistic'
  get   '/server_statistics/reservation/:reservation_id',                  to: 'server_statistics#show_for_reservation',             as: 'show_reservation_server_statistic'

  get   '/login',                         to: 'sessions#new', as: :login
  get   '/users/auth/failure',            to: 'sessions#failure'
  post  '/users/auth/failure',            to: 'sessions#failure'

  get '/rcon-autocomplete/:id', to: 'reservations#rcon_autocomplete', as: 'rcon_autocomplete'

  root to: 'pages#welcome'
  match '*path', via: :all, to: 'pages#not_found' unless Rails.env.test?
end
