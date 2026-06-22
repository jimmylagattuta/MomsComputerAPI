# app/services/revenuecat/customer_linker.rb

module Revenuecat
  class CustomerLinker
    def initialize(user:, app_user_id:)
      @user = user
      @app_user_id = app_user_id.to_s.strip
    end

    def call
      return failure("missing_user") unless @user
      return failure("missing_app_user_id") if @app_user_id.blank?

      debug_log("start", {
        user_id: @user.id,
        app_user_id: @app_user_id
      })

      link = upsert_customer_link!

      replay_result = replay_latest_event

      if replay_result[:subscription_active]
        link.update!(status: "linked_active")

        return success(
          replay_result: replay_result,
          subscription_active: true,
          live_verified: false
        )
      end

      live_result = live_revenuecat_fallback

      if live_result[:subscription_active]
        link.update!(status: "linked_active")

        return success(
          replay_result: replay_result,
          subscription_active: true,
          live_verified: true
        )
      end

      link.update!(status: "linked_inactive")

      success(
        replay_result: replay_result,
        subscription_active: false,
        live_verified: false
      )
    rescue ActiveRecord::RecordNotUnique
      retry
    rescue => e
      Rails.logger.error("[RC_LINK] CustomerLinker failed #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        linked: false,
        subscription_active: false,
        error: "customer_link_failed",
        message: e.message
      }
    end

    private

    def upsert_customer_link!
      link = RevenuecatCustomerLink.find_or_initialize_by(app_user_id: @app_user_id)

      link.assign_attributes(
        user: @user,
        original_app_user_id: link.original_app_user_id.presence || @app_user_id,
        status: "linked"
      )

      link.save!
      link
    end

    def replay_latest_event
      revenuecat_event = find_latest_revenuecat_event

      unless revenuecat_event
        debug_log("replay_result", {
          replayed: false,
          reason: "no_revenuecat_event_found",
          subscription_active: false
        })

        return {
          replayed: false,
          reason: "no_revenuecat_event_found",
          subscription_active: false
        }
      end

      payload = revenuecat_event.raw_payload || {}
      event = payload["event"] || {}

      if event.blank?
        debug_log("replay_result", {
          replayed: false,
          reason: "missing_event_payload",
          event_id: revenuecat_event.id,
          subscription_active: user_subscription_active?
        })

        return {
          replayed: false,
          reason: "missing_event_payload",
          event_id: revenuecat_event.id,
          subscription_active: user_subscription_active?
        }
      end

      debug_log("replay_start", {
        user_id: @user.id,
        app_user_id: @app_user_id,
        revenuecat_event_id: revenuecat_event.id,
        revenuecat_event_type: revenuecat_event.event_type
      })

      # Important:
      # Your RevenuecatWebhookProcessor already finds a user through
      # RevenuecatCustomerLink. Since we upserted the link above, replaying
      # the old webhook payload now attaches the subscription to this user.
      RevenuecatWebhookProcessor.new(
        payload: payload,
        event: event
      ).call

      subscription_active = user_subscription_active?

      debug_log("replay_result", {
        replayed: true,
        event_id: revenuecat_event.id,
        event_type: revenuecat_event.event_type,
        subscription_active: subscription_active
      })

      {
        replayed: true,
        reason: nil,
        event_id: revenuecat_event.id,
        event_type: revenuecat_event.event_type,
        subscription_active: subscription_active
      }
    rescue => e
      Rails.logger.error("[RC_LINK] replay_failed #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        replayed: false,
        reason: "replay_failed",
        error: e.message,
        subscription_active: user_subscription_active?
      }
    end

    def find_latest_revenuecat_event
      scope = RevenuecatEvent.order(created_at: :desc)

      if RevenuecatEvent.column_names.include?("app_user_id")
        found = scope.where(app_user_id: @app_user_id).first
        return found if found
      end

      if RevenuecatEvent.column_names.include?("original_app_user_id")
        found = scope.where(original_app_user_id: @app_user_id).first
        return found if found
      end

      nil
    end

    def live_revenuecat_fallback
      unless defined?(::Revenuecat::CustomerStatusFetcher)
        debug_log("live_customer_lookup_skipped", {
          reason: "customer_status_fetcher_not_defined",
          app_user_id: @app_user_id
        })

        return {
          subscription_active: user_subscription_active?,
          active: false,
          skipped: true,
          reason: "customer_status_fetcher_not_defined"
        }
      end

      debug_log("live_customer_lookup_start", {
        user_id: @user.id,
        app_user_id: @app_user_id
      })

      result = ::Revenuecat::CustomerStatusFetcher.new(
        app_user_id: @app_user_id
      ).call

      debug_log("live_customer_lookup_result", {
        active: result.active?,
        entitlement_key: result.entitlement_key,
        product_id: result.product_id,
        expires_at: result.expires_at
      })

      unless result.active?
        return {
          subscription_active: user_subscription_active?,
          active: false
        }
      end

      sync_active_subscription_from_live_result!(result)

      {
        subscription_active: true,
        active: true,
        entitlement_key: result.entitlement_key,
        product_id: result.product_id,
        expires_at: result.expires_at
      }
    rescue => e
      Rails.logger.error("[RC_LINK] live_customer_lookup_failed #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        subscription_active: user_subscription_active?,
        active: false,
        error: e.message
      }
    end

    def sync_active_subscription_from_live_result!(result)
      subscription = Subscription.find_or_initialize_by(
        user: @user,
        provider: "revenuecat",
        product_id: result.product_id
      )

      subscription.assign_attributes(
        plan: find_plan(result.product_id),
        status: "active",
        revenuecat_app_user_id: @app_user_id,
        revenuecat_original_app_user_id: @app_user_id,
        product_id: result.product_id,
        entitlement_key: result.entitlement_key.presence || "premium",
        current_period_end: result.expires_at,
        last_validated_at: Time.current
      )

      subscription.save!

      entitlement = Entitlement.find_or_initialize_by(
        user: @user,
        key: result.entitlement_key.presence || "premium",
        source: "revenuecat"
      )

      entitlement.enabled = true
      entitlement.expires_at = result.expires_at
      entitlement.save!

      debug_log("live_customer_sync_success", {
        user_id: @user.id,
        app_user_id: @app_user_id,
        product_id: result.product_id,
        entitlement_key: result.entitlement_key,
        expires_at: result.expires_at
      })
    end

    def find_plan(product_id)
      Plan.find_by(provider_product_id: product_id) || Plan.first
    end

    def user_subscription_active?
      subscription_active? || entitlement_active?
    end

    def subscription_active?
      sub = Subscription
        .where(user: @user, provider: "revenuecat")
        .order(updated_at: :desc)
        .first

      return false unless sub

      status_active = sub.status.to_s.in?([
        "active",
        "trialing",
        "paid",
        "subscribed",
        "cancelled"
      ])

      not_expired =
        if sub.current_period_end.present?
          sub.current_period_end.future?
        else
          status_active
        end

      status_active && not_expired
    end

    def entitlement_active?
      entitlement = Entitlement
        .where(user: @user, source: "revenuecat")
        .order(updated_at: :desc)
        .first

      return false unless entitlement
      return false unless entitlement.enabled?

      entitlement.expires_at.blank? || entitlement.expires_at.future?
    end

    def success(replay_result:, subscription_active:, live_verified:)
      payload = {
        linked: true,
        replayed_revenuecat_event: replay_result[:replayed] == true,
        replay_result: replay_result,
        subscription_active: subscription_active,
        live_verified: live_verified,
        link_created_without_existing_webhook: replay_result[:replayed] != true,
        user: user_payload
      }

      debug_log("finish", payload.except(:user))

      payload
    end

    def failure(reason)
      {
        linked: false,
        subscription_active: false,
        error: reason
      }
    end

    def user_payload
      {
        id: @user.id,
        email: @user.try(:email),
        subscription_active: user_subscription_active?
      }
    end

    def debug_log(event, payload = {})
      return unless ENV["DEBUG_RC_LINK"] == "true"

      Rails.logger.info("[RC_LINK] #{event} #{payload.to_json}")
    end
  end
end