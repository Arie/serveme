Serveme::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => "sessions" } 

  devise_scope :user do 
    get '/sessions/auth/:provider' => 'sessions#passthru'
    post '/users/auth/:provider/callback' => 'sessions#steam'
  end

  resources :sessions do
    collection do
      get :steam
      post :passthru
      get :failure
    end
  end
  resources :reservations, :except => [:edit, :update] do
    member do
      post :extend
    end
    collection do
      get :server_selection
    end
  end
  resources :pages do
    collection do
      get :credits
      get :recent_reservations
      get :top_10
    end
  end

  get   '/login', :to => 'sessions#new',  :as => :login
  match '/users/auth/failure',            :to => 'sessions#failure'

  root :to => "pages#welcome"
end
