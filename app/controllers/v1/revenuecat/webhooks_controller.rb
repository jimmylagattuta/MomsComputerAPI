module V1
  module Revenuecat
    class WebhooksController < ApplicationController
      skip_before_action :authenticate_user!, raise: false
      skip_before_action :verify_authenticity_token, raise: false

      def create
        return unauthorized unless valid_revenuecat_webhook?

        payload = JSON.parse(request.raw_post)
        event = payload["event"] || {}

        RevenuecatWebhookProcessor.new(payload: payload, event: event).call

        render json: { received: true }, status: :ok
      rescue JSON::ParserError
        render json: { error: "invalid_json" }, status: :bad_request
      rescue ActiveRecord::RecordNotUnique
        render json: { received: true, duplicate: true }, status: :ok
      rescue => e
        Rails.logger.error("[RevenueCatWebhook] #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))

        render json: { received: false }, status: :internal_server_error
      end

      private

      def valid_revenuecat_webhook?
        expected = ENV["REVENUECAT_WEBHOOK_AUTH_HEADER"].to_s
        received = request.headers["Authorization"].to_s

        return false if expected.blank? || received.blank?

        ActiveSupport::SecurityUtils.secure_compare(received, expected)
      end

      def unauthorized
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end
  end
end