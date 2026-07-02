# app/services/ringcentral/delete_subscription.rb

require "ringcentral"

module Ringcentral
  class DeleteSubscription
    def self.call(subscription_id)
      new(subscription_id).call
    end

    def initialize(subscription_id)
      @subscription_id = subscription_id.to_s.strip
    end

    def call
      return failure!("missing_subscription_id") if subscription_id.blank?

      client_id = ENV.fetch("RINGCENTRAL_CLIENT_ID")
      client_secret = ENV.fetch("RINGCENTRAL_CLIENT_SECRET")
      server_url = ENV.fetch("RINGCENTRAL_SERVER_URL")
      jwt = ENV.fetch("RINGCENTRAL_JWT")

      puts "[RingCentral Delete Subscription] Starting..."
      puts "[RingCentral Delete Subscription] Subscription ID: #{subscription_id}"

      rc = RingCentral.new(client_id, client_secret, server_url)

      puts "[RingCentral Delete Subscription] Authorizing with JWT..."
      rc.authorize(jwt: jwt)

      path = "/restapi/v1.0/subscription/#{subscription_id}"

      puts "[RingCentral Delete Subscription] Deleting #{path}..."
      response = rc.delete(path)

      puts "[RingCentral Delete Subscription] Deleted successfully."
      puts "[RingCentral Delete Subscription] Response: #{response.body.inspect}"

      {
        success: true,
        subscription_id: subscription_id,
        response: response.body
      }
    rescue StandardError => e
      puts "[RingCentral Delete Subscription] FAILED"
      puts "[RingCentral Delete Subscription] #{e.class.name}: #{e.message}"
      puts e.backtrace.first(10)

      {
        success: false,
        subscription_id: subscription_id,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :subscription_id

    def failure!(reason)
      {
        success: false,
        subscription_id: subscription_id,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end
