# app/controllers/v1/revenuecat/customers_controller.rb
module V1
  module Revenuecat
    class CustomersController < ApplicationController
      include JwtAuth

      before_action :authenticate_user!, only: [:link]

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

          # If the replay created/updated subscription records, re-check link status.
          current_user.reload

          subscription_active_after_replay = current_user.support_subscription_active?

          link.update!(
            status: subscription_active_after_replay ? "linked_active" : link.status
          )

          rc_debug(
            "link_status_after_replay",
            link_id: link.id,
            status: link.status,
            subscription_active: subscription_active_after_replay
          )
        end

        current_user.reload

        subscription_active = current_user.support_subscription_active?

        rc_debug(
          "finish",
          linked: true,
          replayed: replayed_event.present?,
          link_created_without_existing_webhook: replayed_event.blank?,
          subscription_active: subscription_active
        )

        render json: {
          linked: true,
          link_created_without_existing_webhook: replayed_event.blank?,
          replayed_revenuecat_event: replayed_event.present?,
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
            # linked, then replay if an event exists.
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