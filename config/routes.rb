Rails.application.routes.draw do
  get "public_pages/sms_consent"
  get "/sms-consent", to: "public_pages#sms_consent"

  mount ActionCable.server => "/cable"

  get   "password_resets/edit", to: "password_resets#edit"
  post  "password_resets",      to: "password_resets#update"
  patch "password_resets",      to: "password_resets#update"

  namespace :v1 do
    get "public_ask_mom/create"

    namespace :revenuecat do
      post :webhooks, to: "webhooks#create"
      post :link_customer, to: "customers#link"
      get  :customer_status, to: "customers#status"
    end

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

    namespace :admin do
      get "dashboard", to: "dashboard#show"

      namespace :billing do
        get :kpis,                to: "/v1/admin/billing#kpis"
        get :recent_events,       to: "/v1/admin/billing#recent_events"
        get :recent_transactions, to: "/v1/admin/billing#recent_transactions"

        # Frontend-friendly alias for the transaction table dropdown item.
        # This points to the same controller action as recent_transactions.
        get :transactions,        to: "/v1/admin/billing#recent_transactions"

        get :subscribers,         to: "/v1/admin/billing#subscribers"
      end

      resources :users, only: [:index, :show, :update] do
        member do
          get   :control_center,    to: "user_controls#show"
          patch :control_calls,     to: "user_controls#update_calls"
          patch :control_account,   to: "user_controls#update_account"
          patch :control_messaging, to: "user_controls#update_messaging"
          patch :control_access,    to: "user_controls#update_access"
          patch :control_security,  to: "user_controls#update_security"
        end
      end

      resources :subscriptions, only: [:index, :show, :update]
      resources :support_threads, only: [:index, :show]
    end

    get    "me", to: "me#show"
    delete "me", to: "me#destroy"

    namespace :auth do
      post "phone/request_code", to: "phone#request_code"
      post "phone/verify_code",  to: "phone#verify_code"

      post  :signup,          to: "auth#signup"
      post  :login,           to: "auth#login"
      post  :logout,          to: "auth#logout"
      patch :change_password, to: "auth#change_password"

      post  :forgot_password, to: "password_resets#create"
      patch :reset_password,  to: "password_resets#update"
    end

    post "twilio_webhooks/voice_bridge",   to: "twilio_webhooks#voice_bridge"
    post "twilio_webhooks/call_status",    to: "twilio_webhooks#call_status"
    post "twilio_webhooks/message_status", to: "twilio_webhooks#message_status"

    post "ringcentral/webhook", to: "ringcentral_webhooks#create"

    post "public_ask_mom", to: "public_ask_mom#create"
    post "ask_mom", to: "ask_mom#create"

    resources :conversations, only: [:index, :show]

    resources :messages, only: [] do
      post :attachments, on: :member, to: "attachments#create"
    end

    resources :escalations, only: [:create]
  end

  get "/portal", to: "portal#index"
  get "/portal/*path", to: "portal#index"
end