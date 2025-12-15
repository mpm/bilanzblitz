Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end
  root "home#index"

  # Onboarding
  get "onboarding", to: "onboarding#new", as: :onboarding
  post "onboarding", to: "onboarding#create"

  # Dashboard
  get "dashboard", to: "dashboard#index", as: :dashboard

  # User Preferences
  patch "user_preferences", to: "user_preferences#update"

  # Reports
  namespace :reports do
    get "balance_sheet", to: "balance_sheets#index"
  end

  # Fiscal Years
  resources :fiscal_years, only: [ :index, :show ] do
    member do
      post :post_opening_balance
      get :preview_closing
      post :close
    end
  end

  # Opening Balances
  resources :opening_balances, only: [ :new, :create ]

  # Accounts API (for account search)
  resources :accounts, only: [ :index ] do
    collection do
      get :recent
    end
  end

  # Journal Entries
  resources :journal_entries, only: [ :index, :create, :update, :destroy ]

  # Documents
  resources :documents, only: [ :index, :create, :update, :destroy ]

  # Bank Accounts
  resources :bank_accounts, only: [ :index, :show ] do
    member do
      post :import_preview
      post :import
    end
  end

  get "inertia-example", to: "inertia_example#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
