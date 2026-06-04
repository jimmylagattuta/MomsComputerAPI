# app/services/ask_mom/public_request_guard.rb
# frozen_string_literal: true

module AskMom
  class PublicRequestGuard
    MAX_RAW_TEXT_BYTES = 2_000
    MAX_GUEST_ID_LENGTH = 120
    MAX_IMAGES = 1
    MAX_IMAGE_BYTES = 4.megabytes

    ALLOWED_IMAGE_TYPES = %w[
      image/jpeg
      image/jpg
      image/png
      image/webp
      image/heic
      image/heif
    ].freeze

    Result = Struct.new(:allowed, :error, :message, :status, keyword_init: true)

    def self.call(guest_id:, text:, images:)
      new(guest_id: guest_id, text: text, images: images).call
    end

    def initialize(guest_id:, text:, images:)
      @guest_id = guest_id.to_s
      @text = text.to_s
      @images = Array(images).compact
    end

    def call
      return deny("missing_guest_id", "Missing guest ID.", :bad_request) if @guest_id.blank?

      if @guest_id.length > MAX_GUEST_ID_LENGTH
        return deny("invalid_guest_id", "Invalid guest session.", :bad_request)
      end

      unless @guest_id.match?(/\A[a-zA-Z0-9_\-:.]{8,120}\z/)
        return deny("invalid_guest_id", "Invalid guest session.", :bad_request)
      end

      if @text.bytesize > MAX_RAW_TEXT_BYTES
        return deny(
          "message_too_large",
          "That message is too long. Please shorten it and try again.",
          :payload_too_large
        )
      end

      if @text.strip.blank? && @images.empty?
        return deny(
          "invalid_request",
          "Please type a message or attach an image.",
          :bad_request
        )
      end

      if @images.length > MAX_IMAGES
        return deny(
          "too_many_images",
          "You can attach 1 image per message.",
          :unprocessable_entity
        )
      end

      @images.each do |img|
        content_type = img.respond_to?(:content_type) ? img.content_type.to_s.downcase : ""
        size = img.respond_to?(:size) ? img.size.to_i : 0

        unless ALLOWED_IMAGE_TYPES.include?(content_type)
          return deny(
            "invalid_image_type",
            "Please upload a JPG, PNG, WEBP, HEIC, or HEIF image.",
            :unprocessable_entity
          )
        end

        if size <= 0 || size > MAX_IMAGE_BYTES
          return deny(
            "image_too_large",
            "That image is too large. Please upload a smaller screenshot or photo.",
            :payload_too_large
          )
        end
      end

      Result.new(allowed: true, error: nil, message: nil, status: :ok)
    end

    private

    def deny(error, message, status)
      Result.new(
        allowed: false,
        error: error,
        message: message,
        status: status
      )
    end
  end
end