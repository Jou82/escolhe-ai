Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  root to: "pages#home"
  resources :sessions, only: [:new, :create, :show, :index] do
    resources :movies, only: [:show], controller: "session_movies"
  end
  resources :movies,   only: [:index, :show]
  resources :likes,    only: [:create]
  resources :movies, only: [:index, :show, :create]


  get "up" => "rails/health#show", as: :rails_health_check
  get "profile", to: "pages#profile", as: :profile
end
