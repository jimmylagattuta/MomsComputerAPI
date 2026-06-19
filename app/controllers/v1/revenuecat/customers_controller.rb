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

        link = find_link(
          app_user_id: app_user_id,
          original_app_user_id: original_app_user_id,
          guest_id: guest_id
        )

        unless link
          return render json: {
            error: "revenuecat_customer_not_found",
            message: "We could not find the guest subscription to link."
          }, status: :not_found
        end

        ActiveRecord::Base.transaction do
          link.update!(
            user: current_user,
            status: active_link?(link) ? "linked_active" : "linked_inactive",
            linked_at: Time.current
          )

          attach_latest_revenuecat_event_to_user!(link, current_user)
        end

        current_user.reload

        render json: {
          linked: true,
          subscription_active: current_user.support_subscription_active?,
          user: user_payload(current_user)
        }
      end

      private

      def find_link(app_user_id:, original_app_user_id:, guest_id:)
        if app_user_id.present?
          RevenuecatCustomerLink.find_by(app_user_id: app_user_id)
        elsif original_app_user_id.present?
          RevenuecatCustomerLink.find_by(original_app_user_id: original_app_user_id)
        elsif guest_id.present?
          RevenuecatCustomerLink.find_by(guest_id: guest_id)
        end
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

      def attach_latest_revenuecat_event_to_user!(link, user)
        event =
          RevenuecatEvent
            .where(app_user_id: [link.app_user_id, link.original_app_user_id].compact)
            .order(created_at: :desc)
            .first

        return unless event

        event.update!(user: user) if event.user_id.blank?

        RevenuecatWebhookProcessor.new(
          payload: event.raw_payload,
          event: event.raw_payload["event"] || {}
        ).call
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