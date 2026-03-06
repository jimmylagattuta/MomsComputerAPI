Rails.application.routes.draw do
  namespace :v1 do
    # Support Calls
    resources :support_calls, only: [:create]

    # Twilio Webhooks
    post "twilio_webhooks/voice_bridge", to: "twilio_webhooks#voice_bridge"
    post "twilio_webhooks/call_status", to: "twilio_webhooks#call_status"

    get "me", to: "me#show"

    namespace :auth do
      post :signup, to: "auth#signup"
      post :login,  to: "auth#login"
      post :logout, to: "auth#logout"
    end

    post "ask_mom", to: "ask_mom#create"

    # Conversation history (Ask Mom drawer)
    resources :conversations, only: [:index, :show]

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    # Leaving this in place is fine, but Ask Mom no longer auto-creates tickets.
    resources :escalations, only: [:create]
  end
end