Rails.application.routes.draw do
  namespace :v1 do
    get "me", to: "me#show"

    namespace :auth do
      post :signup, to: "auth#signup"
      post :login,  to: "auth#login"
      post :logout, to: "auth#logout"
    end

    post "ask_mom", to: "ask_mom#create"

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    # Leaving this in place is fine, but Ask Mom no longer auto-creates tickets.
    resources :escalations, only: [:create]
  end
end