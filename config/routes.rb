Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  root to: "pages#home"
  resources :sessions, only: [:new, :create, :show, :index] do
    resources :movies, only: [:show], controller: "session_movies"
  end
  resources :movies, only: [:index, :show, :create] do # ← :create aqui
    get :search, on: :collection
  end
  resources :likes, only: [:create]

  get "up" => "rails/health#show", as: :rails_health_check
  get "profile", to: "pages#profile", as: :profile
  patch "profile", to: "pages#update_profile", as: :update_profile
end
