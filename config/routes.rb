Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }, skip: [:registrations]

 devise_scope :user do
    post   '/users',         to: 'users/registrations#create'
    patch  '/users',         to: 'users/registrations#update'
    put    '/users',         to: 'users/registrations#update'
    delete '/users',         to: 'users/registrations#destroy'
    get    '/users/cancel',  to: 'users/registrations#cancel', as: 'cancel_user_registration'
    get    '/users/sign_up', to: 'users/registrations#new',  as: 'new_user_registration'
  end

  root to: "pages#home"
  resources :sessions, only: [:new, :create, :show, :index] do
    resources :movies, only: [:show], controller: "session_movies"
  end
  resources :movies, only: [:index, :show, :create]
  resources :likes, only: [:create]

  get "up" => "rails/health#show", as: :rails_health_check
  get "profile", to: "pages#profile", as: :profile
  patch "profile", to: "pages#update_profile", as: :update_profile
end
