Rails.application.routes.draw do
  root "home#index"

  get "submit", to: "posts#new", as: :submit
  post "submit", to: "posts#create"
  get "u/:pseudonym", to: "users#show", as: :profile
  resources :reports, only: :create
  resources :posts, only: [ :show, :edit, :update ] do
    resources :comments, only: :create
    resource :vote, only: :create, controller: "post_votes"
  end
  resources :comments, only: [] do
    resource :vote, only: :create, controller: "comment_votes"
  end

  get "sign-in", to: "sessions#new", as: :sign_in
  post "sign-in", to: "sessions#create"
  delete "sign-out", to: "sessions#destroy", as: :sign_out

  get "sign-up", to: "users#new", as: :sign_up
  post "sign-up", to: "users#create"

  get "password-reset", to: "password_resets#new", as: :password_reset
  post "password-reset", to: "password_resets#create"
  get "password-reset/:token", to: "password_resets#edit", as: :password_reset_token
  patch "password-reset/:token", to: "password_resets#update"

  get "email-verification/:token", to: "email_verifications#show", as: :email_verification

  get "tags/:slug", to: "tags#show", as: :tag
  get "about", to: "static_pages#show", defaults: { page_key: "about" }, as: :about
  get "rules", to: "static_pages#show", defaults: { page_key: "rules" }, as: :rules
  get "faq", to: "static_pages#show", defaults: { page_key: "faq" }, as: :faq
  get "privacy", to: "static_pages#show", defaults: { page_key: "privacy" }, as: :privacy
  get "terms", to: "static_pages#show", defaults: { page_key: "terms" }, as: :terms

  namespace :mod do
    resources :reports, only: [ :index, :show, :update ]
    resources :posts, only: [] do
      patch :moderate, on: :member
    end
    resources :comments, only: [] do
      patch :moderate, on: :member
    end
    resources :users, only: :show do
      patch :moderate, on: :member
    end
    resources :tags, only: [ :index, :create, :update ] do
      patch :merge, on: :collection
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
