# config/routes.rb
Rails.application.routes.draw do
  namespace :v1 do
    resources :support_calls, only: [:create]

    get  "support_text_thread", to: "support_text_threads#current"
    post "support_text_thread", to: "support_text_threads#create"

    resources :support_text_threads, only: [:index, :show]
    resources :support_text_messages, only: [:index, :create]

    namespace :support do
      resources :text_threads, only: [:index, :show, :update] do
        resources :messages, only: [:index, :create], controller: "text_messages"
        post :assign, on: :member
        post :close,  on: :member
        post :block,  on: :member
      end
    end

    get "me", to: "me#show"

    namespace :auth do
      post :signup, to: "auth#signup"
      post :login,  to: "auth#login"
      post :logout, to: "auth#logout"
    end

    post "ask_mom", to: "ask_mom#create"

    resources :conversations, only: [:index, :show]

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    resources :escalations, only: [:create]
  end
end