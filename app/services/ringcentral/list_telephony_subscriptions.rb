# app/services/ringcentral/list_telephony_subscriptions.rb

require "ringcentral"

module Ringcentral
  class ListTelephonySubscriptions
    WEBHOOK_URL = Ringcentral::CreateTelephonySubscription::WEBHOOK_URL
    EVENT_FILTERS = Ringcentral::CreateTelephonySubscription::EVENT_FILTERS

    def self.call
      new.call
    end

    def call
      client_id = ENV.fetch("RINGCENTRAL_CLIENT_ID")
      client_secret = ENV.fetch("RINGCENTRAL_CLIENT_SECRET")
      server_url = ENV.fetch("RINGCENTRAL_SERVER_URL")
      jwt = ENV.fetch("RINGCENTRAL_JWT")

      puts "[RingCentral List Subscriptions] Starting..."
      puts "[RingCentral List Subscriptions] Expected webhook URL: #{WEBHOOK_URL}"
      puts "[RingCentral List Subscriptions] Expected event filters: #{EVENT_FILTERS.inspect}"

      rc = RingCentral.new(client_id, client_secret, server_url)

      puts "[RingCentral List Subscriptions] Authorizing with JWT..."
      rc.authorize(jwt: jwt)

      puts "[RingCentral List Subscriptions] Fetching subscriptions..."
      response = rc.get("/restapi/v1.0/subscription")

      body = response.body
      records = body["records"] || []

      subscriptions = records.map do |record|
        event_filters = record["eventFilters"] || []
        delivery_mode = record["deliveryMode"] || {}

        {
          id: record["id"],
          status: record["status"],
          event_filters: event_filters,
          delivery_transport_type: delivery_mode["transportType"],
          delivery_address: delivery_mode["address"],
          expires_in: record["expiresIn"],
          expiration_time: record["expirationTime"],
          creation_time: record["creationTime"],
          matches_expected_webhook: delivery_mode["address"] == WEBHOOK_URL,
          matches_telephony_sessions: telephony_sessions_filter?(event_filters),
          raw: record
        }
      end

      telephony_subscriptions = subscriptions.select do |subscription|
        subscription[:matches_telephony_sessions]
      end

      puts ""
      puts "========================================"
      puts "RingCentral subscriptions summary"
      puts "========================================"
      puts "Total subscriptions: #{subscriptions.length}"
      puts "Telephony subscriptions: #{telephony_subscriptions.length}"
      puts ""

      subscriptions.each_with_index do |subscription, index|
        puts "----------------------------------------"
        puts "Subscription ##{index + 1}"
        puts "ID: #{subscription[:id]}"
        puts "Status: #{subscription[:status]}"
        puts "Delivery transport: #{subscription[:delivery_transport_type]}"
        puts "Delivery address: #{subscription[:delivery_address]}"
        puts "Expires in: #{subscription[:expires_in]}"
        puts "Expiration time: #{subscription[:expiration_time]}"
        puts "Creation time: #{subscription[:creation_time]}"
        puts "Matches expected webhook?: #{subscription[:matches_expected_webhook]}"
        puts "Matches telephony/sessions?: #{subscription[:matches_telephony_sessions]}"
        puts "Event filters:"
        subscription[:event_filters].each do |event_filter|
          puts "- #{event_filter}"
        end
      end

      puts "----------------------------------------"
      puts ""

      {
        success: true,
        total_count: subscriptions.length,
        telephony_count: telephony_subscriptions.length,
        subscriptions: subscriptions,
        telephony_subscriptions: telephony_subscriptions
      }
    rescue StandardError => e
      puts "[RingCentral List Subscriptions] FAILED"
      puts "[RingCentral List Subscriptions] #{e.class.name}: #{e.message}"
      puts e.backtrace.first(10)

      {
        success: false,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    def telephony_sessions_filter?(event_filters)
      event_filters.any? do |event_filter|
        event_filter.to_s.match?(%r{\A/restapi/v1\.0/account/[^/]+/telephony/sessions\z})
      end
    end
  end
end
