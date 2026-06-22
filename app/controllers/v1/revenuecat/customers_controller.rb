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

        if app_user_id.blank?
          return render json: { error: "missing_app_user_id" }, status: :unprocessable_entity
        end

        result = ::Revenuecat::CustomerLinker.new(
          user: current_user,
          app_user_id: app_user_id
        ).call

        render json: result, status: :ok
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
    end
  end
end