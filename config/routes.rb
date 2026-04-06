Rails.application.routes.draw do
  get "public_pages/sms_consent"
  # ✅ Public pages for compliance / legal
  get "/sms_consent", to: "public_pages#sms_consent"

  # ✅ ActionCable endpoint
  mount ActionCable.server => "/cable"

  get   "password_resets/edit", to: "password_resets#edit"
  post  "password_resets",      to: "password_resets#update"
  patch "password_resets",      to: "password_resets#update"

  namespace :v1 do
    post "devices/register", to: "devices#register"

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
      # 🔥 PHONE VERIFICATION
      post "phone/request_code", to: "phone#request_code"
      post "phone/verify_code",  to: "phone#verify_code"

      # 🔐 AUTH
      post  :signup,          to: "auth#signup"
      post  :login,           to: "auth#login"
      post  :logout,          to: "auth#logout"
      patch :change_password, to: "auth#change_password"

      post  :forgot_password, to: "password_resets#create"
      patch :reset_password,  to: "password_resets#update"
    end

    # 🧠 Twilio Webhooks
    post "twilio_webhooks/voice_bridge", to: "twilio_webhooks#voice_bridge"
    post "twilio_webhooks/call_status",  to: "twilio_webhooks#call_status"
    post "twilio_webhooks/message_status", to: "twilio_webhooks#message_status"

    post "ask_mom", to: "ask_mom#create"

    resources :conversations, only: [:index, :show]

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    resources :escalations, only: [:create]
  end
end