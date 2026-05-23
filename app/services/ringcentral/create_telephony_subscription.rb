# app/services/ringcentral/create_telephony_subscription.rb

require "ringcentral"
require "securerandom"

module Ringcentral
  class CreateTelephonySubscription
    WEBHOOK_URL = "https://moms-computer-api.herokuapp.com/v1/ringcentral/webhook"

    EVENT_FILTERS = [
      "/restapi/v1.0/account/~/extension/~/telephony/sessions"
    ].freeze

    def self.call
      new.call
    end

    def call
      client_id = ENV.fetch("RINGCENTRAL_CLIENT_ID")
      client_secret = ENV.fetch("RINGCENTRAL_CLIENT_SECRET")
      server_url = ENV.fetch("RINGCENTRAL_SERVER_URL")
      jwt = ENV.fetch("RINGCENTRAL_JWT")

      validation_token = ENV["RINGCENTRAL_WEBHOOK_VALIDATION_TOKEN"].presence ||
        SecureRandom.hex(24)

      Rails.logger.info("[RingCentral Subscription] Starting...")
      Rails.logger.info("[RingCentral Subscription] Webhook URL: #{WEBHOOK_URL}")
      Rails.logger.info("[RingCentral Subscription] Event filters: #{EVENT_FILTERS.inspect}")

      rc = RingCentral.new(client_id, client_secret, server_url)

      Rails.logger.info("[RingCentral Subscription] Authorizing with JWT...")
      rc.authorize(jwt: jwt)

      subscription_payload = {
        eventFilters: EVENT_FILTERS,
        deliveryMode: {
          transportType: "WebHook",
          address: WEBHOOK_URL,
          verificationToken: validation_token
        }
      }

      Rails.logger.info("[RingCentral Subscription] Creating subscription...")
      Rails.logger.info("[RingCentral Subscription] Payload: #{subscription_payload.inspect}")

      response = rc.post(
        "/restapi/v1.0/subscription",
        payload: subscription_payload
      )

      body = response.body

      Rails.logger.info("[RingCentral Subscription] Created subscription:")
      Rails.logger.info(body.inspect)

      {
        success: true,
        subscription_id: body["id"],
        status: body["status"],
        event_filters: body["eventFilters"],
        expires_in: body["expiresIn"],
        expiration_time: body["expirationTime"],
        raw: body
      }
    rescue StandardError => e
      Rails.logger.error("[RingCentral Subscription] FAILED")
      Rails.logger.error("[RingCentral Subscription] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        error_class: e.class.name,
        error_message: e.message
      }
    end
  end
end