# app/services/revenuecat/customer_linker.rb

module Revenuecat
  class CustomerLinker
    RECENT_EVENT_DEBUG_LIMIT = 15

    def initialize(user:, app_user_id:)
      @user = user
      @app_user_id = app_user_id.to_s.strip
    end

    def call
      return failure("missing_user") unless @user
      return failure("missing_app_user_id") if @app_user_id.blank?

      debug_log("start", {
        user_id: @user.id,
        user_email: safe_user_email,
        app_user_id: @app_user_id,
        rails_env: Rails.env,
        customer_status_fetcher_defined: defined?(::Revenuecat::CustomerStatusFetcher).present?,
        revenuecat_event_columns: RevenuecatEvent.column_names.sort,
        subscription_columns: Subscription.column_names.sort,
        entitlement_columns: Entitlement.column_names.sort
      })

      debug_user_subscription_state("before_link")
      debug_existing_customer_links
      debug_revenuecat_event_candidates

      link = upsert_customer_link!

      debug_log("link_upserted", {
        link_id: link.id,
        link_user_id: link.user_id,
        app_user_id: link.app_user_id,
        original_app_user_id: link.try(:original_app_user_id),
        guest_id: link.try(:guest_id),
        status: link.status,
        created_at: link.created_at,
        updated_at: link.updated_at
      })

      replay_result = replay_latest_event

      debug_log("after_replay", {
        replay_result: replay_result,
        computed_subscription_active: user_subscription_active?
      })

      debug_user_subscription_state("after_replay")

      if replay_result[:subscription_active]
        link.update!(status: "linked_active")

        return success(
          replay_result: replay_result,
          subscription_active: true,
          live_verified: false
        )
      end

      live_result = live_revenuecat_fallback

      debug_log("after_live_fallback", {
        live_result: live_result,
        computed_subscription_active: user_subscription_active?
      })

      debug_user_subscription_state("after_live_fallback")

      if live_result[:subscription_active]
        link.update!(status: "linked_active")

        return success(
          replay_result: replay_result,
          subscription_active: true,
          live_verified: true
        )
      end

      link.update!(status: "linked_inactive")

      debug_log("link_marked_inactive", {
        link_id: link.id,
        status: link.status,
        computed_subscription_active: user_subscription_active?
      })

      success(
        replay_result: replay_result,
        subscription_active: false,
        live_verified: false
      )
    rescue ActiveRecord::RecordNotUnique
      debug_log("record_not_unique_retry", {
        user_id: @user&.id,
        app_user_id: @app_user_id
      })
      retry
    rescue => e
      Rails.logger.error("[RC_LINK] CustomerLinker failed #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(20).join("\n"))

      {
        linked: false,
        subscription_active: false,
        error: "customer_link_failed",
        message: e.message
      }
    end

    private

    def upsert_customer_link!
      existing = RevenuecatCustomerLink.find_by(app_user_id: @app_user_id)

      debug_log("upsert_customer_link_start", {
        existing_link_id: existing&.id,
        existing_user_id: existing&.user_id,
        existing_status: existing&.status,
        incoming_user_id: @user.id,
        app_user_id: @app_user_id
      })

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
          app_user_id: @app_user_id,
          subscription_active: user_subscription_active?
        })

        debug_revenuecat_event_candidates

        return {
          replayed: false,
          reason: "no_revenuecat_event_found",
          subscription_active: user_subscription_active?
        }
      end

      payload = revenuecat_event.raw_payload || {}
      event = payload["event"] || {}

      debug_log("replay_event_found", revenuecat_event_debug_payload(revenuecat_event))

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
        revenuecat_event_type: revenuecat_event.event_type,
        payload_app_user_id: event["app_user_id"],
        payload_original_app_user_id: event["original_app_user_id"],
        payload_aliases: Array(event["aliases"]),
        payload_product_id: event["product_id"],
        payload_entitlement_ids: event["entitlement_ids"],
        payload_period_type: event["period_type"],
        payload_expiration_at_ms: event["expiration_at_ms"],
        payload_event_timestamp_ms: event["event_timestamp_ms"],
        payload_store: event["store"]
      })

      RevenuecatWebhookProcessor.new(
        payload: payload,
        event: event
      ).call

      subscription_active = user_subscription_active?

      debug_user_subscription_state("after_webhook_replay")

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
      Rails.logger.error(e.backtrace.first(20).join("\n"))

      {
        replayed: false,
        reason: "replay_failed",
        error: e.message,
        subscription_active: user_subscription_active?
      }
    end

    def find_latest_revenuecat_event
      scope = RevenuecatEvent.order(created_at: :desc)

      debug_log("event_lookup_start", {
        app_user_id: @app_user_id,
        has_app_user_id_column: RevenuecatEvent.column_names.include?("app_user_id"),
        has_original_app_user_id_column: RevenuecatEvent.column_names.include?("original_app_user_id"),
        total_event_count: RevenuecatEvent.count
      })

      if RevenuecatEvent.column_names.include?("app_user_id")
        found = scope.where(app_user_id: @app_user_id).first

        debug_log("event_lookup_app_user_id", {
          app_user_id: @app_user_id,
          found: found.present?,
          event_id: found&.id,
          event_type: found&.event_type,
          created_at: found&.created_at
        })

        return found if found
      end

      if RevenuecatEvent.column_names.include?("original_app_user_id")
        found = scope.where(original_app_user_id: @app_user_id).first

        debug_log("event_lookup_original_app_user_id", {
          original_app_user_id: @app_user_id,
          found: found.present?,
          event_id: found&.id,
          event_type: found&.event_type,
          created_at: found&.created_at
        })

        return found if found
      end

      # Diagnostic alias scan:
      # RevenueCat may send the current anonymous/customer ID as an alias
      # rather than storing it in our app_user_id/original_app_user_id columns.
      alias_match = find_latest_event_by_payload_identity

      debug_log("event_lookup_payload_identity", {
        app_user_id: @app_user_id,
        found: alias_match.present?,
        event_id: alias_match&.id,
        event_type: alias_match&.event_type,
        created_at: alias_match&.created_at
      })

      alias_match
    end

    def find_latest_event_by_payload_identity
      RevenuecatEvent
        .order(created_at: :desc)
        .limit(RECENT_EVENT_DEBUG_LIMIT)
        .detect do |record|
          payload = record.raw_payload || {}
          event = payload["event"] || {}

          candidates = [
            event["app_user_id"],
            event["original_app_user_id"],
            *Array(event["aliases"])
          ].compact.map(&:to_s)

          candidates.include?(@app_user_id)
        end
    rescue => e
      debug_log("event_lookup_payload_identity_failed", {
        error_class: e.class.name,
        error: e.message
      })
      nil
    end

    def live_revenuecat_fallback
      unless defined?(::Revenuecat::CustomerStatusFetcher)
        debug_log("live_customer_lookup_skipped", {
          reason: "customer_status_fetcher_not_defined",
          app_user_id: @app_user_id,
          rails_env: Rails.env,
          autoload_paths_include_services: Rails.application.config.autoload_paths.any? { |p| p.to_s.include?("services") },
          eager_load_paths_include_services: Rails.application.config.eager_load_paths.any? { |p| p.to_s.include?("services") }
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
        app_user_id: @app_user_id,
        fetcher_class: ::Revenuecat::CustomerStatusFetcher.name
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
      Rails.logger.error(e.backtrace.first(20).join("\n"))

      {
        subscription_active: user_subscription_active?,
        active: false,
        error: e.message
      }
    end

    def sync_active_subscription_from_live_result!(result)
      debug_log("live_customer_sync_start", {
        user_id: @user.id,
        app_user_id: @app_user_id,
        product_id: result.product_id,
        entitlement_key: result.entitlement_key,
        expires_at: result.expires_at
      })

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
        subscription_id: subscription.id,
        subscription_status: subscription.status,
        product_id: result.product_id,
        entitlement_id: entitlement.id,
        entitlement_key: result.entitlement_key,
        expires_at: result.expires_at
      })
    end

    def find_plan(product_id)
      direct = Plan.find_by(provider_product_id: product_id)

      debug_log("find_plan", {
        product_id: product_id,
        direct_plan_id: direct&.id,
        direct_provider_product_id: direct&.try(:provider_product_id),
        fallback_plan_id: direct ? nil : Plan.first&.id,
        available_plans: Plan.limit(20).map do |plan|
          {
            id: plan.id,
            provider_product_id: plan.try(:provider_product_id),
            name: plan.try(:name),
            active: plan.try(:active)
          }
        end
      })

      direct || Plan.first
    end

    def user_subscription_active?
      subscription_result = subscription_active?
      entitlement_result = entitlement_active?
      result = subscription_result || entitlement_result

      debug_log("user_subscription_active_check", {
        user_id: @user.id,
        subscription_active: subscription_result,
        entitlement_active: entitlement_result,
        result: result
      })

      result
    end

    def subscription_active?
      sub = Subscription
        .where(user: @user, provider: "revenuecat")
        .order(updated_at: :desc)
        .first

      unless sub
        debug_log("subscription_active_check", {
          user_id: @user.id,
          found: false,
          result: false
        })
        return false
      end

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

      result = status_active && not_expired

      debug_log("subscription_active_check", {
        user_id: @user.id,
        found: true,
        subscription_id: sub.id,
        provider: sub.provider,
        status: sub.status,
        product_id: sub.try(:product_id),
        plan_id: sub.try(:plan_id),
        entitlement_key: sub.try(:entitlement_key),
        revenuecat_app_user_id: sub.try(:revenuecat_app_user_id),
        revenuecat_original_app_user_id: sub.try(:revenuecat_original_app_user_id),
        current_period_end: sub.try(:current_period_end),
        last_validated_at: sub.try(:last_validated_at),
        updated_at: sub.updated_at,
        status_active: status_active,
        not_expired: not_expired,
        result: result
      })

      result
    end

    def entitlement_active?
      entitlement = Entitlement
        .where(user: @user, source: "revenuecat")
        .order(updated_at: :desc)
        .first

      unless entitlement
        debug_log("entitlement_active_check", {
          user_id: @user.id,
          found: false,
          result: false
        })
        return false
      end

      enabled = entitlement.enabled?
      not_expired = entitlement.expires_at.blank? || entitlement.expires_at.future?
      result = enabled && not_expired

      debug_log("entitlement_active_check", {
        user_id: @user.id,
        found: true,
        entitlement_id: entitlement.id,
        key: entitlement.key,
        source: entitlement.source,
        enabled: enabled,
        expires_at: entitlement.expires_at,
        updated_at: entitlement.updated_at,
        not_expired: not_expired,
        result: result
      })

      result
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

      debug_user_subscription_state("finish")

      debug_log("finish", payload.except(:user).merge(
        user_payload: payload[:user]
      ))

      payload
    end

    def failure(reason)
      debug_log("failure", {
        reason: reason,
        user_id: @user&.id,
        app_user_id: @app_user_id
      })

      {
        linked: false,
        subscription_active: false,
        error: reason
      }
    end

    def user_payload
      {
        id: @user.id,
        email: safe_user_email,
        subscription_active: user_subscription_active?
      }
    end

    def debug_existing_customer_links
      links = RevenuecatCustomerLink
        .where(user: @user)
        .order(updated_at: :desc)
        .limit(20)

      debug_log("existing_customer_links", {
        user_id: @user.id,
        count: links.size,
        links: links.map do |link|
          {
            id: link.id,
            app_user_id: link.app_user_id,
            original_app_user_id: link.try(:original_app_user_id),
            guest_id: link.try(:guest_id),
            status: link.status,
            created_at: link.created_at,
            updated_at: link.updated_at
          }
        end
      })
    rescue => e
      debug_log("existing_customer_links_failed", {
        error_class: e.class.name,
        error: e.message
      })
    end

    def debug_user_subscription_state(label)
      subscriptions = Subscription
        .where(user: @user)
        .order(updated_at: :desc)
        .limit(20)

      entitlements = Entitlement
        .where(user: @user)
        .order(updated_at: :desc)
        .limit(20)

      debug_log("user_subscription_state", {
        label: label,
        user_id: @user.id,
        subscriptions: subscriptions.map do |sub|
          {
            id: sub.id,
            provider: sub.try(:provider),
            status: sub.try(:status),
            plan_id: sub.try(:plan_id),
            product_id: sub.try(:product_id),
            entitlement_key: sub.try(:entitlement_key),
            revenuecat_app_user_id: sub.try(:revenuecat_app_user_id),
            revenuecat_original_app_user_id: sub.try(:revenuecat_original_app_user_id),
            current_period_end: sub.try(:current_period_end),
            last_validated_at: sub.try(:last_validated_at),
            created_at: sub.created_at,
            updated_at: sub.updated_at
          }
        end,
        entitlements: entitlements.map do |entitlement|
          {
            id: entitlement.id,
            key: entitlement.try(:key),
            source: entitlement.try(:source),
            enabled: entitlement.try(:enabled),
            expires_at: entitlement.try(:expires_at),
            created_at: entitlement.created_at,
            updated_at: entitlement.updated_at
          }
        end
      })
    rescue => e
      debug_log("user_subscription_state_failed", {
        label: label,
        error_class: e.class.name,
        error: e.message
      })
    end

    def debug_revenuecat_event_candidates
      events = RevenuecatEvent
        .order(created_at: :desc)
        .limit(RECENT_EVENT_DEBUG_LIMIT)

      debug_log("recent_revenuecat_events", {
        searching_for_app_user_id: @app_user_id,
        count: events.size,
        events: events.map { |record| revenuecat_event_debug_payload(record) }
      })
    rescue => e
      debug_log("recent_revenuecat_events_failed", {
        error_class: e.class.name,
        error: e.message
      })
    end

    def revenuecat_event_debug_payload(record)
      payload = record.raw_payload || {}
      event = payload["event"] || {}

      identities = [
        record.try(:app_user_id),
        record.try(:original_app_user_id),
        event["app_user_id"],
        event["original_app_user_id"],
        *Array(event["aliases"])
      ].compact.map(&:to_s).uniq

      {
        id: record.id,
        event_type: record.try(:event_type),
        db_app_user_id: record.try(:app_user_id),
        db_original_app_user_id: record.try(:original_app_user_id),
        payload_app_user_id: event["app_user_id"],
        payload_original_app_user_id: event["original_app_user_id"],
        payload_aliases: Array(event["aliases"]),
        payload_product_id: event["product_id"],
        payload_entitlement_ids: event["entitlement_ids"],
        payload_store: event["store"],
        payload_period_type: event["period_type"],
        payload_environment: event["environment"],
        payload_expiration_at_ms: event["expiration_at_ms"],
        payload_purchased_at_ms: event["purchased_at_ms"],
        payload_event_timestamp_ms: event["event_timestamp_ms"],
        identity_matches_current_app_user_id: identities.include?(@app_user_id),
        created_at: record.created_at
      }
    end

    def safe_user_email
      @user.try(:email)
    end

    def debug_log(event, payload = {})
      return unless ENV["DEBUG_RC_LINK"] == "true"

      Rails.logger.info("[RC_LINK] #{event} #{payload.to_json}")
    end
  end
end