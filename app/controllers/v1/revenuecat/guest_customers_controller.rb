# app/controllers/v1/revenuecat/guest_customers_controller.rb

module V1
  module Revenuecat
    class GuestCustomersController < ApplicationController
      skip_before_action :authenticate_user!, only: [:remember], raise: false

      # POST /v1/revenuecat/remember_guest_customer
      #
      # Public endpoint.
      #
      # Called while the app is logged out.
      # Saves:
      # guest_id + RevenueCat anonymous app_user_id
      #
      # Example body:
      # {
      #   "guest_id": "guest_abc123",
      #   "app_user_id": "$RCAnonymousID:abc123",
      #   "original_app_user_id": "$RCAnonymousID:abc123"
      # }
      def remember
        guest_id = clean_param(params[:guest_id])
        app_user_id = clean_param(params[:app_user_id])
        original_app_user_id = clean_param(params[:original_app_user_id]) || app_user_id

        if guest_id.blank?
          return render json: { error: "missing_guest_id" }, status: :unprocessable_entity
        end

        if app_user_id.blank?
          return render json: { error: "missing_app_user_id" }, status: :unprocessable_entity
        end

        unless revenuecat_anonymous_id?(app_user_id)
          return render json: { error: "app_user_id_must_be_anonymous" }, status: :unprocessable_entity
        end

        link = RevenuecatCustomerLink.find_or_initialize_by(app_user_id: app_user_id)

        link.guest_id = guest_id
        link.original_app_user_id = original_app_user_id
        link.status = link.user_id.present? ? "linked" : "pending"

        # Optional fields if your model/table has them.
        assign_if_column_exists(link, :last_seen_at, Time.current)

        link.save!

        debug_log("remember_guest_customer", {
          guest_id: guest_id,
          app_user_id: app_user_id,
          original_app_user_id: original_app_user_id,
          link_id: link.id,
          user_id: link.user_id,
          status: link.status
        })

        render json: {
          remembered: true,
          linked: link.user_id.present?,
          status: link.status
        }, status: :ok
      rescue ActiveRecord::RecordNotUnique
        retry
      rescue => e
        Rails.logger.error("[RC_GUEST] remember_failed #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))

        render json: { error: "remember_failed" }, status: :internal_server_error
      end

      # POST /v1/revenuecat/attach_guest_customer
      #
      # Authenticated endpoint.
      #
      # Called immediately after signup/login, after auth_token is saved.
      #
      # Example body:
      # {
      #   "guest_id": "guest_abc123"
      # }
      def attach
        guest_id = clean_param(params[:guest_id])
        explicit_app_user_id = clean_param(params[:app_user_id])

        if guest_id.blank? && explicit_app_user_id.blank?
          return render json: { error: "missing_guest_id_or_app_user_id" }, status: :unprocessable_entity
        end

        link =
          if explicit_app_user_id.present?
            RevenuecatCustomerLink.where(app_user_id: explicit_app_user_id).order(updated_at: :desc).first
          else
            RevenuecatCustomerLink.where(guest_id: guest_id).order(updated_at: :desc).first
          end

        unless link
          debug_log("attach_guest_customer_missing_link", {
            user_id: current_user.id,
            guest_id: guest_id,
            explicit_app_user_id: explicit_app_user_id
          })

          return render json: {
            linked: false,
            subscription_active: false,
            error: "no_pending_guest_customer"
          }, status: :not_found
        end

        link.update!(
          user_id: current_user.id,
          status: "linked"
        )

        debug_log("attach_guest_customer_linked", {
          user_id: current_user.id,
          guest_id: guest_id,
          app_user_id: link.app_user_id,
          original_app_user_id: link.original_app_user_id,
          link_id: link.id
        })

        # Reuse your existing link endpoint logic.
        # This is intentionally simple:
        # after attaching by guest_id, run the same backend verification path
        # using the saved anonymous RevenueCat app_user_id.
        result = link_revenuecat_customer_to_current_user(link.app_user_id)

        render json: result.merge(
          linked: true,
          guest_attached: true,
          guest_id: guest_id,
          app_user_id: link.app_user_id
        ), status: :ok
      rescue => e
        Rails.logger.error("[RC_GUEST] attach_failed #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))

        render json: { error: "attach_failed" }, status: :internal_server_error
      end

      private

      def clean_param(value)
        value.to_s.strip.presence
      end

      def revenuecat_anonymous_id?(value)
        value.to_s.start_with?("$RCAnonymousID:")
      end

      def assign_if_column_exists(record, column_name, value)
        return unless record.respond_to?("#{column_name}=")
        record.public_send("#{column_name}=", value)
      end

      def debug_log(event, payload = {})
        return unless ENV["DEBUG_RC_LINK"] == "true"

        Rails.logger.info("[RC_GUEST] #{event} #{payload.to_json}")
      end

      # This calls the same service/path your existing /link_customer controller uses.
      #
      # If your CustomersController already has this logic inline instead of a service,
      # we will move that logic into a small service next.
      def link_revenuecat_customer_to_current_user(app_user_id)
        linker = ::Revenuecat::CustomerLinker.new(
          user: current_user,
          app_user_id: app_user_id
        )

        linker.call
      end
    end
  end
end