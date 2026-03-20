Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  root to: "pages#home"

  resources :sessions, only: [:new, :create, :show, :index]
  resources :movies,   only: [:index, :show, :create]
  resources :likes,    only: [:create]

  get  "profile", to: "pages#profile",         as: :profile
  patch "profile", to: "pages#update_profile", as: :update_profile
  get  "up",      to: "rails/health#show",     as: :rails_health_check
end
