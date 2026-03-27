# app/services/expo_push_service.rb
require "net/http"
require "uri"
require "json"

class ExpoPushService
  EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send".freeze
  MAX_BATCH_SIZE = 100

  class << self
    def send_to_tokens!(tokens:, title:, body:, data: {}, sound: "default", priority: "high", channel_id: nil)
      cleaned_tokens = normalize_tokens(tokens)

      if cleaned_tokens.empty?
        Rails.logger.info("[ExpoPushService] No valid Expo push tokens to send.")
        return {
          ok: true,
          skipped: true,
          reason: "no_valid_tokens",
          responses: []
        }
      end

      responses = []

      cleaned_tokens.each_slice(MAX_BATCH_SIZE) do |token_batch|
        messages = token_batch.map do |token|
          payload = {
            to: token,
            title: title,
            body: body,
            data: data,
            sound: sound,
            priority: priority
          }

          payload[:channelId] = channel_id if channel_id.present?
          payload
        end

        responses << post_messages(messages)
      end

      {
        ok: true,
        skipped: false,
        token_count: cleaned_tokens.size,
        batch_count: responses.size,
        responses: responses
      }
    rescue => e
      Rails.logger.error("[ExpoPushService] send_to_tokens! failed: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

      {
        ok: false,
        skipped: false,
        error_class: e.class.name,
        error_message: e.message,
        responses: responses || []
      }
    end

    def valid_expo_push_token?(token)
      token.is_a?(String) && token.match?(/\AExponentPushToken\[[^\]]+\]\z|\AExpoPushToken\[[^\]]+\]\z/)
    end

    def normalize_tokens(tokens)
      Array(tokens)
        .flatten
        .compact
        .map(&:to_s)
        .map(&:strip)
        .reject(&:blank?)
        .uniq
        .select { |token| valid_expo_push_token?(token) }
    end

    private

    def post_messages(messages)
      uri = URI.parse(EXPO_PUSH_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 20

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = messages.to_json

      Rails.logger.info("[ExpoPushService] Sending #{messages.size} push notification(s) to Expo.")

      response = http.request(request)
      parsed_body = parse_json(response.body)

      Rails.logger.info(
        "[ExpoPushService] Response status=#{response.code} body=#{truncate_for_logs(parsed_body.inspect)}"
      )

      {
        http_status: response.code.to_i,
        raw_body: parsed_body
      }
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      { "raw_body" => body }
    end

    def truncate_for_logs(value, max_length = 1500)
      return value if value.length <= max_length
      "#{value[0...max_length]}...[truncated]"
    end
  end
end