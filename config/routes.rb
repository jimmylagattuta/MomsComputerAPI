Rails.application.routes.draw do
  namespace :v1 do
    get "me", to: "me#show"

    namespace :auth do
      post :signup, to: "auth#signup"
      post :login,  to: "auth#login"
    end

    post "ask_mom", to: "ask_mom#create"

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    resources :escalations, only: [:create]
  end
end
