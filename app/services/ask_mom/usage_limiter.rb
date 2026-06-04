# app/services/ask_mom/usage_limiter.rb
# frozen_string_literal: true

module AskMom
  class UsageLimiter
    Result = Struct.new(
      :allowed,
      :error,
      :message,
      :status,
      :limits,
      keyword_init: true
    )

    def initialize(actor_key:, tier:, limits:, conversation_key:)
      @actor_key = actor_key.to_s
      @tier = tier.to_s
      @limits = limits
      @conversation_key = conversation_key.to_s
    end

    def check!(text:, image_count:, new_conversation:)
      text = text.to_s
      image_count = image_count.to_i
      usage = usage_payload

      if text.length > @limits[:chars_per_message].to_i
        return deny(
          "message_too_long",
          "That message is too long. Please shorten it and try again.",
          :unprocessable_entity
        )
      end

      if image_count > @limits[:images_per_message].to_i
        return deny(
          "too_many_images",
          "You can attach up to #{@limits[:images_per_message]} image(s) per message.",
          :unprocessable_entity
        )
      end

      if usage[:messages_used_today] >= @limits[:messages_per_day].to_i
        return deny(
          "daily_message_limit_reached",
          "You’ve reached today’s Ask Mom message limit.",
          :too_many_requests
        )
      end

      if usage[:images_used_today] + image_count > @limits[:images_per_day].to_i
        return deny(
          "daily_image_limit_reached",
          "You’ve reached today’s Ask Mom image limit.",
          :too_many_requests
        )
      end

      if new_conversation && usage[:conversations_used_today] >= @limits[:conversations_per_day].to_i
        return deny(
          "daily_conversation_limit_reached",
          "You’ve reached today’s Ask Mom conversation limit.",
          :too_many_requests
        )
      end

      if usage[:messages_used_in_conversation] >= @limits[:messages_per_conversation].to_i
        return deny(
          "conversation_message_limit_reached",
          "This Ask Mom conversation has reached its message limit.",
          :too_many_requests
        )
      end

      unless burst_allowed?
        return deny(
          "rate_limited",
          "Too many messages too quickly. Please wait a moment and try again.",
          :too_many_requests
        )
      end

      allow
    end

    def increment!(image_count:, new_conversation:)
      image_count = image_count.to_i

      daily = read_hash(daily_key)
      convo = read_hash(conversation_cache_key)

      daily["messages_used_today"] = daily["messages_used_today"].to_i + 1
      daily["images_used_today"] = daily["images_used_today"].to_i + image_count
      daily["conversations_used_today"] = daily["conversations_used_today"].to_i + 1 if new_conversation

      convo["messages_used_in_conversation"] = convo["messages_used_in_conversation"].to_i + 1

      Rails.cache.write(daily_key, daily, expires_in: seconds_until_tomorrow.seconds)
      Rails.cache.write(conversation_cache_key, convo, expires_in: seconds_until_tomorrow.seconds)

      usage_payload
    end

    def usage_payload
      daily = read_hash(daily_key)
      convo = read_hash(conversation_cache_key)

      {
        tier: @tier,

        messages_used_today: daily["messages_used_today"].to_i,
        messages_allowed_today: @limits[:messages_per_day].to_i,

        images_used_today: daily["images_used_today"].to_i,
        images_allowed_today: @limits[:images_per_day].to_i,

        conversations_used_today: daily["conversations_used_today"].to_i,
        conversations_allowed_today: @limits[:conversations_per_day].to_i,

        messages_used_in_conversation: convo["messages_used_in_conversation"].to_i,
        messages_allowed_per_conversation: @limits[:messages_per_conversation].to_i,

        reset_at: Date.tomorrow.beginning_of_day.iso8601
      }
    end

    private

    def allow
      Result.new(
        allowed: true,
        error: nil,
        message: nil,
        status: :ok,
        limits: usage_payload
      )
    end

    def deny(error, message, status)
      Result.new(
        allowed: false,
        error: error,
        message: message,
        status: status,
        limits: usage_payload
      )
    end

    def daily_key
      "ask_mom:usage:#{Date.current.iso8601}:#{@actor_key}"
    end

    def conversation_cache_key
      "ask_mom:conversation:#{Date.current.iso8601}:#{@conversation_key}"
    end

    def burst_key
      "ask_mom:burst:#{@actor_key}"
    end

    def burst_allowed?
      now = Time.current.to_f
      window_seconds = @limits[:burst_seconds].to_i
      max_messages = @limits[:burst_messages].to_i

      timestamps = Rails.cache.read(burst_key)
      timestamps = [] unless timestamps.is_a?(Array)

      timestamps = timestamps.select { |ts| ts.to_f >= now - window_seconds }

      return false if timestamps.length >= max_messages

      timestamps << now
      Rails.cache.write(burst_key, timestamps, expires_in: window_seconds.seconds)

      true
    end

    def read_hash(key)
      raw = Rails.cache.read(key)
      raw.is_a?(Hash) ? raw : {}
    rescue => e
      Rails.logger.warn("[AskMom::UsageLimiter] cache read failed key=#{key}: #{e.class} - #{e.message}")
      {}
    end

    def seconds_until_tomorrow
      [(Date.tomorrow.beginning_of_day - Time.current).to_i, 60].max
    end
  end
end