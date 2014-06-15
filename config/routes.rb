require 'sidekiq/web'
require 'sidetiq/web'

Serveme::Application.routes.draw do

  get "/404", :to => "pages#not_found"
  get "/500", :to => "pages#error"

  devise_for :users, :controllers => { :omniauth_callbacks => "sessions" }

  devise_scope :user do
    get '/sessions/auth/:provider' => 'sessions#passthru'
    post '/users/auth/:provider/callback' => 'sessions#steam'
    get '/users/auth/:provider/callback' => 'sessions#steam'
    delete "/users/logout" => "devise/sessions#destroy"
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
      post :extend_reservation, :as => :extend
      post :idle_reset,         :as => :idle_reset
    end
    collection do
      post :find_servers_for_user
      patch :find_servers_for_reservation
      post :time_selection
      post :i_am_feeling_lucky
    end
    resources :log_uploads, :only => [:new, :create, :index] do
      collection do
        get :show_log
      end
    end
  end

  resources :map_uploads, :only => [:new, :create]

  resources :pages do
    collection do
      get :credits
      get :recent_reservations
      get :statistics
      get :server_providers
      get :faq
    end
  end

  resources :donators

  resources :servers, :only => :index

  resources :paypal_orders, :only => [:new, :create] do
    collection do
      get :redirect
    end
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  namespace :api do
    resources :reservations do
      collection do
        post :find_servers
      end
    end
  end


  #Pretty URLs
  get   '/donate',                        :to => "paypal_orders#new",         :as => "donate"
  get   '/statistics',                    :to => "pages#statistics",          :as => "statistics"
  get   '/faq',                           :to => "pages#faq",                 :as => "faq"
  get   '/credits',                       :to => "pages#credits",             :as => "credits"
  get   '/server-providers',              :to => "pages#server_providers",    :as => "server_providers"
  get   '/your-reservations',             :to => "reservations#index",        :as => "your_reservations"
  get   '/reservations-played',           :to => "reservations#played_in",    :as => "played_in"
  get   '/recent-reservations',           :to => "pages#recent_reservations", :as => "recent_reservations"
  get   '/settings',                      :to => "users#edit",                :as => "settings"
  get   '/switch-theme',                  :to => "pages#switch_theme",        :as => "switch_theme"
  get   '/upload-map',                    :to => "map_uploads#new",           :as => "upload_map"

  get   '/login',                         :to => 'sessions#new',      :as => :login
  get   '/users/auth/failure',            :to => 'sessions#failure'
  post  '/users/auth/failure',            :to => 'sessions#failure'

  root :to => "pages#welcome"
end
