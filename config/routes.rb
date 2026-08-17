Rails.application.routes.draw do
  root "books#index"
  resources :books, only: [:index, :show] do
    resources :reviews, only: [:create, :update, :destroy]
  end
  resources :users, only: [:index, :show] do
    member do
      post :ban
      post :unban
    end
  end
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
end
