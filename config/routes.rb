Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  root to: "pages#home"

  resources :sessions, only: [:new, :create, :show, :index]
  resources :movies,   only: [:index, :show]
  resources :likes,    only: [:create]

  get "up" => "rails/health#show", as: :rails_health_check
  get "profile", to: "pages#profile", as: :profile
end
