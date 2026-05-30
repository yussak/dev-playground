Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "health", to: "health#index"
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      delete "auth/logout", to: "auth#logout"
      resources :products do
        resources :coupons, only: [ :create, :index, :update, :destroy ]
      end

      resources :product_variants, only: [] do
        resource :stock, only: [ :update ]
      end

      resource :cart, only: [ :show ] do
        resources :items, only: [ :create, :update, :destroy ], controller: "cart_items"
      end

      resources :orders, only: [ :index, :show, :create ] do
        member do
          patch :cancel
        end
      end
    end
  end
end
