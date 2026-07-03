# app/services/ringcentral/ensure_telephony_subscription.rb

require "ringcentral"

module Ringcentral
  class EnsureTelephonySubscription
    WEBHOOK_URL = Ringcentral::CreateTelephonySubscription::WEBHOOK_URL
    RENEWAL_THRESHOLD = 24.hours

    def self.call
      new.call
    end

    def call
      puts "[RingCentral Ensure Subscription] Starting..."
      puts "[RingCentral Ensure Subscription] Webhook URL: #{WEBHOOK_URL}"

      remote_subscriptions = fetch_remote_subscriptions
      matching_subscriptions = remote_subscriptions.select { |subscription| matching_subscription?(subscription) }

      puts "[RingCentral Ensure Subscription] Total remote subscriptions: #{remote_subscriptions.length}"
      puts "[RingCentral Ensure Subscription] Matching telephony subscriptions: #{matching_subscriptions.length}"

      if matching_subscriptions.empty?
        puts "[RingCentral Ensure Subscription] No matching subscription found. Creating one..."

        created = Ringcentral::CreateTelephonySubscription.call
        return failure!("create_failed", created) unless created[:success]

        persisted = persist_from_hash!(created[:raw])
        return success!("created_new_subscription", persisted, created)
      end

      kept = choose_subscription_to_keep(matching_subscriptions)
      extras = matching_subscriptions.reject { |subscription| subscription["id"] == kept["id"] }

      puts "[RingCentral Ensure Subscription] Keeping subscription: #{kept["id"]}"
      puts "[RingCentral Ensure Subscription] Extra subscriptions to delete: #{extras.map { |s| s["id"] }.inspect}"

      deleted_extras = delete_extra_subscriptions(extras)
      persisted_kept = persist_from_hash!(kept)

      if expires_soon?(kept)
        puts "[RingCentral Ensure Subscription] Kept subscription expires soon. Creating replacement..."

        created = Ringcentral::CreateTelephonySubscription.call
        return failure!("replacement_create_failed", created) unless created[:success]

        replacement = persist_from_hash!(created[:raw])
        delete_result = Ringcentral::DeleteSubscription.call(kept["id"])

        persisted_kept.update!(status: "Deleted") if delete_result[:success]

        return success!(
          "replaced_expiring_subscription",
          replacement,
          {
            created: created,
            deleted_old: delete_result,
            deleted_extras: deleted_extras
          }
        )
      end

      success!(
        extras.any? ? "kept_one_deleted_extras" : "already_healthy",
        persisted_kept,
        {
          kept_remote: kept,
          deleted_extras: deleted_extras
        }
      )
    rescue StandardError => e
      puts "[RingCentral Ensure Subscription] FAILED"
      puts "[RingCentral Ensure Subscription] #{e.class.name}: #{e.message}"
      puts e.backtrace.first(10)

      {
        success: false,
        action: "error",
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    def rc_client
      rc = RingCentral.new(
        ENV.fetch("RINGCENTRAL_CLIENT_ID"),
        ENV.fetch("RINGCENTRAL_CLIENT_SECRET"),
        ENV.fetch("RINGCENTRAL_SERVER_URL")
      )

      rc.authorize(jwt: ENV.fetch("RINGCENTRAL_JWT"))
      rc
    end

    def fetch_remote_subscriptions
      response = rc_client.get("/restapi/v1.0/subscription")
      body = response.body || {}
      body["records"] || []
    end

    def matching_subscription?(record)
      return false unless record["status"] == "Active"

      delivery_mode = record["deliveryMode"] || {}

      return false unless delivery_mode["address"] == WEBHOOK_URL
      return false unless delivery_mode["transportType"] == "WebHook"

      telephony_sessions_filter?(record["eventFilters"] || [])
    end

    def telephony_sessions_filter?(event_filters)
      event_filters.any? do |event_filter|
        event_filter.to_s.match?(%r{\A/restapi/v1\.0/account/[^/]+(?:/extension/[^/]+)?/telephony/sessions\z})
      end
    end

    def choose_subscription_to_keep(subscriptions)
      subscriptions.max_by do |subscription|
        [
          parse_time(subscription["expirationTime"]) || Time.at(0),
          parse_time(subscription["creationTime"]) || Time.at(0),
          subscription["id"].to_s
        ]
      end
    end

    def delete_extra_subscriptions(extras)
      extras.map do |subscription|
        puts "[RingCentral Ensure Subscription] Deleting extra subscription: #{subscription["id"]}"

        result = Ringcentral::DeleteSubscription.call(subscription["id"])

        local = RingcentralSubscription.find_by(subscription_id: subscription["id"])
        local&.update!(status: "Deleted") if result[:success]

        {
          subscription_id: subscription["id"],
          result: result
        }
      end
    end

    def expires_soon?(record)
      expiration_time = parse_time(record["expirationTime"])
      return true unless expiration_time.present?

      expiration_time <= RENEWAL_THRESHOLD.from_now
    end

    def persist_from_hash!(record)
      delivery_mode = record["deliveryMode"] || {}

      RingcentralSubscription
        .find_or_initialize_by(subscription_id: record["id"])
        .tap do |subscription|
          subscription.status = record["status"]
          subscription.event_filters = record["eventFilters"] || []
          subscription.delivery_transport_type = delivery_mode["transportType"]
          subscription.delivery_address = delivery_mode["address"]
          subscription.expires_in = record["expiresIn"]
          subscription.expiration_time = parse_time(record["expirationTime"])
          subscription.creation_time = parse_time(record["creationTime"])
          subscription.last_seen_at = Time.current
          subscription.raw_payload = record
          subscription.save!
        end
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def success!(action, subscription, details = {})
      result = {
        success: true,
        action: action,
        subscription_id: subscription.subscription_id,
        status: subscription.status,
        expiration_time: subscription.expiration_time,
        details: details
      }

      puts "[RingCentral Ensure Subscription] SUCCESS #{result.inspect}"

      result
    end

    def failure!(action, details = {})
      result = {
        success: false,
        action: action,
        details: details
      }

      puts "[RingCentral Ensure Subscription] FAILURE #{result.inspect}"

      result
    end
  end
end
