# app/controllers/v1/public_ask_mom_controller.rb
module V1
  class PublicAskMomController < ApplicationController
    skip_before_action :authenticate_user!, raise: false

    def create
      uploaded_images = params[:images]
      uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
      uploaded_images = uploaded_images.compact

      guest_id = params[:guest_id].to_s.strip
      text = params[:text].to_s.strip

      request_guard = AskMom::PublicRequestGuard.call(
        guest_id: guest_id,
        text: text,
        images: uploaded_images
      )

      unless request_guard.allowed
        return render json: {
          error: request_guard.error,
          message: request_guard.message
        }, status: request_guard.status
      end

      limits = AskMom::Limits.for_guest

      # Use a stable server-side digest for cache keys instead of the raw guest_id.
      # This keeps guest IDs out of cache keys/log-ish places while preserving
      # the same limit identity for the same device guest ID.
      guest_key = Digest::SHA256.hexdigest(guest_id)

      limiter = AskMom::UsageLimiter.new(
        actor_key: "guest:#{guest_key}",
        tier: :guest,
        limits: limits,
        conversation_key: "guest:#{guest_key}:public"
      )

      new_conversation = first_guest_message_today?(guest_key)

      check = limiter.check!(
        text: text,
        image_count: uploaded_images.length,
        new_conversation: new_conversation
      )

      unless check.allowed
        return render json: {
          error: check.error,
          message: check.message,
          limits: check.limits
        }, status: check.status
      end

      image_urls =
        if uploaded_images.any?
          AskMom::PublicImageUploader.call(images: uploaded_images)
        else
          []
        end

      ai = AskMom::PublicResponder.new(
        text: text,
        image_urls: image_urls
      ).call

      summary = ai[:summary].to_s.strip
      steps = ai[:steps].is_a?(Array) ? ai[:steps].map(&:to_s).reject(&:blank?) : []

      if summary.blank?
        return render json: {
          error: "assistant_unavailable",
          message: "Ask Mom could not answer right now. Please try again.",
          limits: limiter.usage_payload
        }, status: :bad_gateway
      end

      updated_limits = limiter.increment!(
        image_count: uploaded_images.length,
        new_conversation: new_conversation
      )

      render json: {
        guest_id: guest_id,
        risk_level: ai[:risk_level],
        summary: summary,
        steps: steps,
        escalate_suggested: !!ai[:escalate_suggested],
        confidence: ai[:confidence].to_f,
        show_contact_panel: false,
        escalation_reason: nil,
        limits: updated_limits
      }, status: :ok
    rescue => e
      Rails.logger.error("❌ [PUBLIC_ASK_MOM] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(12).join("\n")) if e.backtrace

      render json: {
        error: "public_ask_mom_failed",
        message: "Ask Mom could not answer right now. Please try again."
      }, status: :internal_server_error
    end

    private

    def first_guest_message_today?(guest_key)
      key = "ask_mom:conversation:#{Date.current.iso8601}:guest:#{guest_key}:public"
      raw = Rails.cache.read(key)

      raw.blank? || raw["messages_used_in_conversation"].to_i <= 0
    rescue => e
      Rails.logger.warn("[PUBLIC_ASK_MOM] first_guest_message_today? failed: #{e.class} - #{e.message}")
      true
    end
  end
end