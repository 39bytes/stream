Rails.application.routes.draw do
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Defines the root path route ("/")
  root "posts#index"

  resources :posts, only: [:index, :create, :update, :destroy]

  get "auth/user", to: "sessions#user"
  get "auth/login", to: "sessions#login"
  get "auth/logout", to: "sessions#logout"
  get "auth/authorized", to: "sessions#authorized"

  post "attachments/upload", to: "attachments#create"
end
