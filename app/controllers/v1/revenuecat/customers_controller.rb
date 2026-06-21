# app/controllers/v1/revenuecat/customers_controller.rb
require "net/http"
require "uri"
require "json"
require "cgi"

module V1
  module Revenuecat
    class CustomersController < ApplicationController
      include JwtAuth

      before_action :authenticate_user!, only: [:link]

      REVENUECAT_API_BASE_URL = "https://api.revenuecat.com/v1".freeze

      def status
        app_user_id = params[:app_user_id].to_s.strip
        original_app_user_id = params[:original_app_user_id].to_s.strip
        guest_id = params[:guest_id].to_s.strip

        link = find_link(
          app_user_id: app_user_id,
          original_app_user_id: original_app_user_id,
          guest_id: guest_id
        )

        render json: {
          active: active_link?(link),
          status: link&.status || "unknown",
          app_user_id: link&.app_user_id,
          original_app_user_id: link&.original_app_user_id,
          guest_id: link&.guest_id,
          linked: link&.user_id.present?,
          linked_user_id: link&.user_id,
          product_id: link&.product_id,
          entitlement_key: link&.entitlement_key,
          expiration_at: link&.expiration_at
        }
      end

      def link
        app_user_id = params[:app_user_id].to_s.strip
        original_app_user_id = params[:original_app_user_id].to_s.strip
        guest_id = params[:guest_id].to_s.strip

        rc_debug(
          "start",
          user_id: current_user.id,
          app_user_id: app_user_id.presence,
          original_app_user_id: original_app_user_id.presence,
          guest_id: guest_id.presence
        )

        link = find_link(
          app_user_id: app_user_id,
          original_app_user_id: original_app_user_id,
          guest_id: guest_id
        )

        rc_debug(
          "link_lookup",
          found: link.present?,
          link_id: link&.id,
          link_user_id: link&.user_id,
          status: link&.status,
          app_user_id: link&.app_user_id,
          original_app_user_id: link&.original_app_user_id,
          guest_id: link&.guest_id,
          last_event_id: link.respond_to?(:last_event_id) ? link.last_event_id : nil
        )

        # Launch-safe fallback:
        # If the RevenueCat webhook/customer-link row was not created yet,
        # do not fail the account setup flow. Create the link from the provided
        # anonymous RevenueCat app_user_id and attach it to the current user.
        link ||= build_missing_link!(
          app_user_id: app_user_id,
          original_app_user_id: original_app_user_id,
          guest_id: guest_id,
          user: current_user
        )

        unless link
          rc_debug(
            "finish",
            linked: false,
            error: "missing_revenuecat_customer_identifier",
            subscription_active: current_user.support_subscription_active?
          )

          return render json: {
            error: "missing_revenuecat_customer_identifier",
            message: "No RevenueCat customer identifier was provided."
          }, status: :unprocessable_entity
        end

        rc_debug(
          "link_ready",
          link_id: link.id,
          link_user_id: link.user_id,
          status: link.status,
          app_user_id: link.app_user_id,
          original_app_user_id: link.original_app_user_id,
          guest_id: link.guest_id,
          active_link: active_link?(link)
        )

        replayed_event = nil
        live_verified = false
        live_sync_result = nil

        ActiveRecord::Base.transaction do
          link.update!(
            user: current_user,
            status: active_link?(link) ? "linked_active" : "linked_inactive",
            linked_at: Time.current
          )

          rc_debug(
            "link_attached_to_user",
            link_id: link.id,
            user_id: current_user.id,
            status: link.status
          )

          replayed_event = attach_latest_revenuecat_event_to_user!(link, current_user)

          # If no local webhook event exists, verify directly with RevenueCat.
          #
          # This is the anonymous-subscribe -> create-account rescue path:
          # local dev may not receive the webhook, the webhook may be delayed,
          # or the webhook may have gone to Heroku while this Rails process is
          # local. The link call only sends an app_user_id, so Rails still must
          # verify that app_user_id with RevenueCat before granting backend access.
          if replayed_event.blank? && !current_user.reload.support_subscription_active?
            live_sync_result = sync_from_live_revenuecat_customer!(link, current_user)
            live_verified = live_sync_result[:active] == true
          end

          # If the replay or live sync created/updated subscription records,
          # re-check link status.
          current_user.reload

          subscription_active_after_sync = current_user.support_subscription_active?

          link.update!(
            status: subscription_active_after_sync ? "linked_active" : link.status
          )

          rc_debug(
            "link_status_after_sync",
            link_id: link.id,
            status: link.status,
            replayed: replayed_event.present?,
            live_verified: live_verified,
            subscription_active: subscription_active_after_sync
          )
        end

        current_user.reload

        subscription_active = current_user.support_subscription_active?

        rc_debug(
          "finish",
          linked: true,
          replayed: replayed_event.present?,
          live_verified: live_verified,
          link_created_without_existing_webhook: replayed_event.blank?,
          subscription_active: subscription_active
        )

        render json: {
          linked: true,
          link_created_without_existing_webhook: replayed_event.blank?,
          replayed_revenuecat_event: replayed_event.present?,
          live_revenuecat_verified: live_verified,
          live_revenuecat_result: live_sync_result,
          subscription_active: subscription_active,
          user: user_payload(current_user)
        }
      end

      private

      def rc_debug(message, data = {})
        return unless ENV["DEBUG_RC_LINK"] == "true"

        clean_data = data.compact.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")
        Rails.logger.info("[RC_LINK] #{message} #{clean_data}".strip)
      end

      def find_link(app_user_id:, original_app_user_id:, guest_id:)
        if app_user_id.present?
          RevenuecatCustomerLink.find_by(app_user_id: app_user_id)
        elsif original_app_user_id.present?
          RevenuecatCustomerLink.find_by(original_app_user_id: original_app_user_id)
        elsif guest_id.present?
          RevenuecatCustomerLink.find_by(guest_id: guest_id)
        end
      end

      def build_missing_link!(app_user_id:, original_app_user_id:, guest_id:, user:)
        usable_app_user_id = app_user_id.presence || original_app_user_id.presence

        if usable_app_user_id.blank? && guest_id.blank?
          rc_debug(
            "missing_link_build_skipped",
            reason: "no_customer_identifier",
            user_id: user&.id
          )

          return nil
        end

        latest_event = latest_revenuecat_event_for(
          app_user_id: usable_app_user_id,
          original_app_user_id: original_app_user_id
        )

        rc_debug(
          "missing_link_latest_event_lookup",
          found: latest_event.present?,
          revenuecat_event_id: latest_event&.id,
          event_id: latest_event&.event_id,
          event_type: latest_event&.event_type,
          event_app_user_id: latest_event&.app_user_id,
          event_original_app_user_id: latest_event&.original_app_user_id,
          event_user_id: latest_event&.user_id
        )

        event_payload = latest_event&.raw_payload || {}
        event_body = event_payload["event"] || {}

        expiration_at = parse_time(
          event_body["expiration_at_ms"] ||
            event_body["expiration_at"] ||
            event_body["expires_at"] ||
            event_body["expiration_date"]
        )

        product_id =
          event_body["product_id"].presence ||
          event_body["product_identifier"].presence ||
          event_body["store_product_id"].presence

        entitlement_key =
          event_body["entitlement_id"].presence ||
          event_body["entitlement_identifier"].presence ||
          event_body["entitlement"].presence

        status =
          if latest_event.present?
            expiration_at.blank? || expiration_at.future? ? "linked_active" : "linked_inactive"
          else
            # We do not know backend subscription status yet, but the frontend
            # only sends this after RevenueCat saw an anonymous customer. Keep it
            # linked, then replay if an event exists or verify live with RevenueCat.
            "linked_inactive"
          end

        link = RevenuecatCustomerLink.create!(
          app_user_id: usable_app_user_id,
          original_app_user_id: original_app_user_id.presence,
          guest_id: guest_id.presence,
          user: user,
          status: status,
          product_id: product_id,
          entitlement_key: entitlement_key,
          expiration_at: expiration_at,
          linked_at: Time.current
        )

        rc_debug(
          "missing_link_created",
          link_id: link.id,
          user_id: user&.id,
          status: link.status,
          app_user_id: link.app_user_id,
          original_app_user_id: link.original_app_user_id,
          guest_id: link.guest_id,
          product_id: link.product_id,
          entitlement_key: link.entitlement_key,
          expiration_at: link.expiration_at
        )

        link
      end

      def active_link?(link)
        return false unless link

        active_statuses = [
          "active",
          "anonymous_active",
          "linked_active",
          "cancelled",
          "anonymous_cancelled",
          "linked_cancelled"
        ]

        active_statuses.include?(link.status.to_s) &&
          (link.expiration_at.blank? || link.expiration_at.future?)
      end

      def latest_revenuecat_event_for(app_user_id:, original_app_user_id:)
        ids = [app_user_id, original_app_user_id].compact_blank.uniq
        return nil if ids.blank?

        RevenuecatEvent
          .where(app_user_id: ids)
          .order(created_at: :desc)
          .first
      end

      def attach_latest_revenuecat_event_to_user!(link, user)
        event =
          latest_revenuecat_event_for(
            app_user_id: link.app_user_id,
            original_app_user_id: link.original_app_user_id
          )

        rc_debug(
          "latest_event_lookup",
          found: event.present?,
          revenuecat_event_id: event&.id,
          event_id: event&.event_id,
          event_type: event&.event_type,
          event_app_user_id: event&.app_user_id,
          event_original_app_user_id: event&.original_app_user_id,
          event_user_id: event&.user_id
        )

        unless event
          rc_debug(
            "replay_result",
            replayed: false,
            reason: "no_revenuecat_event_found",
            app_user_id: link.app_user_id,
            original_app_user_id: link.original_app_user_id,
            user_id: user&.id,
            subscription_active: user.reload.support_subscription_active?
          )

          return nil
        end

        rc_debug(
          "replay_start",
          revenuecat_event_id: event.id,
          event_id: event.event_id,
          event_type: event.event_type,
          existing_event_user_id: event.user_id,
          attaching_to_user_id: user.id
        )

        event.update!(user: user) if event.user_id.blank?

        RevenuecatWebhookProcessor.new(
          payload: event.raw_payload,
          event: event.raw_payload["event"] || {}
        ).call

        rc_debug(
          "replay_result",
          replayed: true,
          revenuecat_event_id: event.id,
          event_id: event.event_id,
          event_type: event.event_type,
          event_user_id: event.reload.user_id,
          subscription_active: user.reload.support_subscription_active?
        )

        event
      end

      # ---------------------------------------------------------------------
      # Live RevenueCat fallback
      # ---------------------------------------------------------------------
      #
      # Webhooks are still the source of truth for normal production sync.
      # This fallback only runs when /link_customer cannot find a local
      # RevenuecatEvent to replay. It verifies the RevenueCat customer directly
      # with the server-side REST API before creating backend premium state.
      #
      # Required env var, one of:
      #   REVENUECAT_SECRET_API_KEY
      #   REVENUECAT_REST_API_KEY
      #   REVENUECAT_V1_API_KEY
      #   REVENUECAT_API_KEY
      #
      # Use a RevenueCat secret/server key here. Do not use mobile public SDK keys.
      def sync_from_live_revenuecat_customer!(link, user)
        app_user_id = link.app_user_id.presence || link.original_app_user_id.presence

        if app_user_id.blank?
          rc_debug(
            "live_customer_lookup_skipped",
            reason: "missing_app_user_id",
            link_id: link.id,
            user_id: user.id
          )

          return { attempted: false, active: false, reason: "missing_app_user_id" }
        end

        api_key = revenuecat_rest_api_key

        if api_key.blank?
          rc_debug(
            "live_customer_lookup_skipped",
            reason: "missing_revenuecat_rest_api_key",
            link_id: link.id,
            user_id: user.id,
            app_user_id: app_user_id
          )

          return { attempted: false, active: false, reason: "missing_revenuecat_rest_api_key" }
        end

        rc_debug(
          "live_customer_lookup_start",
          link_id: link.id,
          user_id: user.id,
          app_user_id: app_user_id
        )

        response = fetch_revenuecat_subscriber(app_user_id: app_user_id, api_key: api_key)

        unless response[:ok]
          rc_debug(
            "live_customer_lookup_failed",
            link_id: link.id,
            user_id: user.id,
            app_user_id: app_user_id,
            status: response[:status],
            reason: response[:reason]
          )

          return {
            attempted: true,
            active: false,
            reason: response[:reason] || "revenuecat_lookup_failed",
            status: response[:status]
          }
        end

        customer_state = extract_live_customer_state(response[:json])

        rc_debug(
          "live_customer_lookup_result",
          link_id: link.id,
          user_id: user.id,
          app_user_id: app_user_id,
          active: customer_state[:active],
          source: customer_state[:source],
          entitlement_key: customer_state[:entitlement_key],
          product_id: customer_state[:product_id],
          store: customer_state[:store],
          expiration_at: customer_state[:expiration_at]
        )

        unless customer_state[:active]
          return {
            attempted: true,
            active: false,
            reason: "no_active_revenuecat_entitlement",
            status: response[:status],
            app_user_id: app_user_id,
            entitlement_key: customer_state[:entitlement_key],
            product_id: customer_state[:product_id],
            expiration_at: customer_state[:expiration_at]
          }
        end

        sync_live_customer_state_to_backend!(
          link: link,
          user: user,
          app_user_id: app_user_id,
          customer_state: customer_state,
          raw_payload: response[:json]
        )

        {
          attempted: true,
          active: true,
          reason: "verified_live_revenuecat_customer",
          status: response[:status],
          app_user_id: app_user_id,
          entitlement_key: customer_state[:entitlement_key],
          product_id: customer_state[:product_id],
          store: customer_state[:store],
          expiration_at: customer_state[:expiration_at]
        }
      rescue => e
        Rails.logger.error("[RC_LINK] live_customer_sync_error #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

        rc_debug(
          "live_customer_sync_error",
          link_id: link&.id,
          user_id: user&.id,
          error_class: e.class.name,
          error_message: e.message
        )

        {
          attempted: true,
          active: false,
          reason: "live_customer_sync_error",
          error_class: e.class.name,
          error_message: e.message
        }
      end

      def revenuecat_rest_api_key
        ENV["REVENUECAT_SECRET_API_KEY"].presence ||
          ENV["REVENUECAT_REST_API_KEY"].presence ||
          ENV["REVENUECAT_V1_API_KEY"].presence ||
          ENV["REVENUECAT_API_KEY"].presence
      end

      def revenuecat_authorization_header(api_key)
        key = api_key.to_s.strip
        key.start_with?("Bearer ") ? key : "Bearer #{key}"
      end

      def fetch_revenuecat_subscriber(app_user_id:, api_key:)
        encoded_app_user_id = CGI.escape(app_user_id.to_s)
        uri = URI("#{REVENUECAT_API_BASE_URL}/subscribers/#{encoded_app_user_id}")

        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        request["Authorization"] = revenuecat_authorization_header(api_key)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 8

        response = http.request(request)
        body = response.body.to_s

        json =
          begin
            body.present? ? JSON.parse(body) : {}
          rescue JSON::ParserError
            {}
          end

        if response.code.to_i.between?(200, 299)
          { ok: true, status: response.code.to_i, json: json }
        else
          {
            ok: false,
            status: response.code.to_i,
            json: json,
            reason: json["message"].presence || json["error"].presence || "revenuecat_http_#{response.code}"
          }
        end
      rescue => e
        {
          ok: false,
          status: nil,
          json: {},
          reason: "revenuecat_request_error",
          error_class: e.class.name,
          error_message: e.message
        }
      end

      def extract_live_customer_state(json)
        subscriber = json["subscriber"] || {}
        entitlements = subscriber["entitlements"] || {}
        subscriptions = subscriber["subscriptions"] || {}

        active_entitlement =
          entitlements
            .map { |key, data| normalize_revenuecat_entitlement(key, data) }
            .compact
            .find { |data| active_revenuecat_expiration?(data[:expiration_at]) }

        if active_entitlement
          product_data = subscriptions[active_entitlement[:product_id].to_s] || {}

          return {
            active: true,
            source: "entitlement",
            entitlement_key: active_entitlement[:entitlement_key],
            product_id: active_entitlement[:product_id],
            store: product_data["store"],
            environment: product_data["environment"],
            transaction_id: product_data["transaction_id"],
            original_transaction_id: product_data["original_transaction_id"],
            purchased_at: parse_time(product_data["purchase_date"] || product_data["purchase_date_ms"]),
            expiration_at: active_entitlement[:expiration_at],
            raw_entitlement: active_entitlement[:raw],
            raw_subscription: product_data
          }
        end

        active_subscription =
          subscriptions
            .map { |product_id, data| normalize_revenuecat_subscription(product_id, data) }
            .compact
            .find { |data| active_revenuecat_expiration?(data[:expiration_at]) }

        if active_subscription
          return {
            active: true,
            source: "subscription",
            entitlement_key: "pro",
            product_id: active_subscription[:product_id],
            store: active_subscription[:store],
            environment: active_subscription[:environment],
            transaction_id: active_subscription[:transaction_id],
            original_transaction_id: active_subscription[:original_transaction_id],
            purchased_at: active_subscription[:purchased_at],
            expiration_at: active_subscription[:expiration_at],
            raw_entitlement: nil,
            raw_subscription: active_subscription[:raw]
          }
        end

        newest_entitlement =
          entitlements
            .map { |key, data| normalize_revenuecat_entitlement(key, data) }
            .compact
            .max_by { |data| data[:expiration_at] || Time.zone.at(0) }

        newest_subscription =
          subscriptions
            .map { |product_id, data| normalize_revenuecat_subscription(product_id, data) }
            .compact
            .max_by { |data| data[:expiration_at] || Time.zone.at(0) }

        {
          active: false,
          source: newest_entitlement ? "entitlement" : newest_subscription ? "subscription" : "none",
          entitlement_key: newest_entitlement&.dig(:entitlement_key) || "pro",
          product_id: newest_entitlement&.dig(:product_id) || newest_subscription&.dig(:product_id),
          store: newest_subscription&.dig(:store),
          environment: newest_subscription&.dig(:environment),
          transaction_id: newest_subscription&.dig(:transaction_id),
          original_transaction_id: newest_subscription&.dig(:original_transaction_id),
          purchased_at: newest_subscription&.dig(:purchased_at),
          expiration_at: newest_entitlement&.dig(:expiration_at) || newest_subscription&.dig(:expiration_at),
          raw_entitlement: newest_entitlement&.dig(:raw),
          raw_subscription: newest_subscription&.dig(:raw)
        }
      end

      def normalize_revenuecat_entitlement(key, data)
        body = data || {}

        {
          entitlement_key: key.to_s.presence || body["entitlement_id"].presence || "pro",
          product_id: body["product_identifier"].presence || body["product_id"].presence,
          expiration_at: parse_time(
            body["expires_date"] ||
              body["expiration_date"] ||
              body["expires_at"] ||
              body["expiration_at"] ||
              body["expires_date_ms"] ||
              body["expiration_at_ms"]
          ),
          raw: body
        }
      end

      def normalize_revenuecat_subscription(product_id, data)
        body = data || {}

        {
          product_id: product_id.to_s.presence || body["product_identifier"].presence || body["product_id"].presence,
          store: body["store"],
          environment: body["environment"],
          transaction_id: body["transaction_id"],
          original_transaction_id: body["original_transaction_id"],
          purchased_at: parse_time(body["purchase_date"] || body["purchase_date_ms"]),
          expiration_at: parse_time(
            body["expires_date"] ||
              body["expiration_date"] ||
              body["expires_at"] ||
              body["expiration_at"] ||
              body["expires_date_ms"] ||
              body["expiration_at_ms"]
          ),
          raw: body
        }
      end

      def active_revenuecat_expiration?(expiration_at)
        expiration_at.blank? || expiration_at.future?
      end

      def sync_live_customer_state_to_backend!(link:, user:, app_user_id:, customer_state:, raw_payload:)
        product_id = customer_state[:product_id].presence || link.product_id.presence
        entitlement_key = customer_state[:entitlement_key].presence || link.entitlement_key.presence || "pro"
        expiration_at = customer_state[:expiration_at]
        purchased_at = customer_state[:purchased_at]
        store = customer_state[:store]
        environment = customer_state[:environment]
        transaction_id = customer_state[:transaction_id]
        original_transaction_id = customer_state[:original_transaction_id]

        subscription = find_or_initialize_revenuecat_subscription(user)

        plan =
          if defined?(Plan) && product_id.present?
            Plan.find_by(provider_product_id: product_id)
          end

        assign_if_column(subscription, :plan, plan) if plan
        assign_if_column(subscription, :provider, "revenuecat")
        assign_if_column(subscription, :revenuecat_app_user_id, app_user_id)
        assign_if_column(subscription, :revenuecat_original_app_user_id, link.original_app_user_id.presence || app_user_id)
        assign_if_column(subscription, :product_id, product_id)
        assign_if_column(subscription, :entitlement_key, entitlement_key)
        assign_if_column(subscription, :store, store)
        assign_if_column(subscription, :environment, environment)
        assign_if_column(subscription, :transaction_id, transaction_id)
        assign_if_column(subscription, :original_transaction_id, original_transaction_id)
        assign_if_column(subscription, :billing_period, infer_billing_period_from_product(product_id, plan))
        assign_if_column(subscription, :current_period_start, purchased_at)
        assign_if_column(subscription, :current_period_end, expiration_at)
        assign_if_column(subscription, :status, "active")
        assign_if_column(subscription, :last_validated_at, Time.current)
        assign_if_column(subscription, :cancel_at_period_end, false)
        assign_if_column(subscription, :cancelled_at, nil)
        assign_if_column(subscription, :billing_issue_at, nil)
        assign_if_column(subscription, :expired_at, nil)

        subscription.save!

        sync_live_entitlement_to_backend!(
          user: user,
          entitlement_key: entitlement_key,
          expiration_at: expiration_at
        )

        link.assign_attributes(
          status: "linked_active",
          product_id: product_id,
          entitlement_key: entitlement_key,
          store: store,
          environment: environment,
          expiration_at: expiration_at,
          linked_at: Time.current
        )

        if link.respond_to?(:last_event_type=)
          link.last_event_type = "LIVE_REVENUECAT_SYNC"
        end

        link.save!

        rc_debug(
          "live_customer_sync_success",
          link_id: link.id,
          user_id: user.id,
          subscription_id: subscription.id,
          entitlement_key: entitlement_key,
          product_id: product_id,
          expiration_at: expiration_at,
          subscription_active: user.reload.support_subscription_active?
        )

        subscription
      end

      def find_or_initialize_revenuecat_subscription(user)
        if Subscription.column_names.include?("provider")
          Subscription.find_or_initialize_by(user: user, provider: "revenuecat")
        else
          Subscription.where(user_id: user.id).first_or_initialize
        end
      end

      def sync_live_entitlement_to_backend!(user:, entitlement_key:, expiration_at:)
        return unless defined?(Entitlement)

        key = entitlement_key.presence || "pro"

        entitlement =
          if Entitlement.column_names.include?("source")
            Entitlement.find_or_initialize_by(user: user, key: key, source: "revenuecat")
          else
            Entitlement.find_or_initialize_by(user: user, key: key)
          end

        assign_if_column(entitlement, :source, "revenuecat")
        assign_if_column(entitlement, :enabled, true)
        assign_if_column(entitlement, :active, true)
        assign_if_column(entitlement, :expires_at, expiration_at)
        assign_if_column(entitlement, :expiration_at, expiration_at)

        entitlement.save!

        entitlement
      end

      def assign_if_column(record, attribute, value)
        attribute_name = attribute.to_s

        if record.respond_to?("#{attribute_name}=")
          record.public_send("#{attribute_name}=", value)
        elsif record.class.respond_to?(:column_names) && record.class.column_names.include?(attribute_name)
          record[attribute_name] = value
        end
      end

      def infer_billing_period_from_product(product_id, plan)
        return plan.billing_period if plan&.respond_to?(:billing_period) && plan.billing_period.present?

        product = product_id.to_s.downcase
        return "yearly" if product.include?("year") || product.include?("annual")
        return "monthly" if product.include?("month")

        nil
      end

      def parse_time(value)
        return nil if value.blank?

        if value.is_a?(Numeric)
          # RevenueCat timestamps are often milliseconds.
          timestamp = value.to_i
          timestamp = timestamp / 1000 if timestamp > 10_000_000_000
          return Time.zone.at(timestamp)
        end

        str = value.to_s.strip
        return nil if str.blank?

        if str.match?(/\A\d+\z/)
          timestamp = str.to_i
          timestamp = timestamp / 1000 if timestamp > 10_000_000_000
          return Time.zone.at(timestamp)
        end

        Time.zone.parse(str)
      rescue
        nil
      end

      def user_payload(user)
        call_usage = call_usage_payload_for(user)

        {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
          first_name: user.first_name,
          last_name: user.last_name,
          phone: user.phone,
          preferred_name: user.preferred_name,
          preferred_language: user.preferred_language,
          timezone: user.timezone,
          date_of_birth: user.date_of_birth,
          marketing_opt_in: user.marketing_opt_in,
          created_at: user.created_at,
          updated_at: user.updated_at,
          last_login_at: user.last_login_at,
          last_seen_at: user.last_seen_at,
          phone_verified_at: user.phone_verified_at,
          support_subscription_active: user.support_subscription_active?,
          current_calls_this_month: call_usage[:current_calls_this_month],
          monthly_call_limit: call_usage[:monthly_call_limit],
          calls_left_this_month: call_usage[:calls_left_this_month],
          active_call_cycle_id: call_usage[:active_call_cycle_id],
          call_cycle_start_at: call_usage[:call_cycle_start_at],
          call_cycle_end_at: call_usage[:call_cycle_end_at]
        }
      end

      def call_usage_payload_for(user)
        active_cycle =
          if defined?(SupportCallCycle)
            SupportCallCycle
              .where(user_id: user.id)
              .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
              .order(cycle_start_at: :desc)
              .first
          end

        calls_allowed = active_cycle ? active_cycle.calls_allowed.to_i : 3
        calls_used = active_cycle ? active_cycle.calls_used.to_i : 0

        {
          current_calls_this_month: calls_used,
          monthly_call_limit: calls_allowed,
          calls_left_this_month: [calls_allowed - calls_used, 0].max,
          active_call_cycle_id: active_cycle&.id,
          call_cycle_start_at: active_cycle&.cycle_start_at,
          call_cycle_end_at: active_cycle&.cycle_end_at
        }
      rescue => e
        Rails.logger.error(
          "❌ [RevenueCatCustomers] call usage failed user_id=#{user&.id}: #{e.class} - #{e.message}"
        )

        {
          current_calls_this_month: 0,
          monthly_call_limit: 3,
          calls_left_this_month: 3,
          active_call_cycle_id: nil,
          call_cycle_start_at: nil,
          call_cycle_end_at: nil
        }
      end
    end
  end
end
