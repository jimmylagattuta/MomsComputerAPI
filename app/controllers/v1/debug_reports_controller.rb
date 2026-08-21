require "digest"
require "json"

module V1
  class DebugReportsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    MAX_REQUEST_BYTES = 1_500_000
    MAX_STRING_LENGTH = 20_000
    MAX_ARRAY_ITEMS = 500
    MAX_HASH_KEYS = 500

    SENSITIVE_KEY_PATTERN =
      /(authorization|password|password_confirmation|token|push[_-]?token|receipt|secret|api[_-]?key|cookie)/i

    JWT_PATTERN =
      /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/

    def create
      if request.content_length.to_i > MAX_REQUEST_BYTES
        return render json: {
          ok: false,
          error: "debug_report_too_large"
        }, status: :payload_too_large
      end

      unless rate_limit_allowed?
        return render json: {
          ok: false,
          error: "too_many_debug_reports"
        }, status: :too_many_requests
      end

      raw_report = params.require(:debug_report).to_unsafe_h
      report = sanitize_value(raw_report)

      report_id =
        "dbg_#{Time.current.utc.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4)}"

      request_meta = {
        report_id: report_id,
        received_at: Time.current.utc.iso8601(6),
        request_id: request.request_id,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent.to_s.first(1_000)
      }

      Rails.logger.info(
        "[DebugReports] received " \
        "report_id=#{report_id} " \
        "ip_digest=#{Digest::SHA256.hexdigest(request.remote_ip.to_s)[0, 16]} " \
        "report_type=#{report['reportType'].inspect} " \
        "generated_at=#{report['generatedAt'].inspect}"
      )

      DebugReportMailer
        .with(report: report, request_meta: request_meta)
        .debug_report
        .deliver_now

      Rails.logger.info(
        "[DebugReports] emailed report_id=#{report_id}"
      )

      render json: {
        ok: true,
        report_id: report_id
      }, status: :ok
    rescue ActionController::ParameterMissing
      render json: {
        ok: false,
        error: "missing_debug_report"
      }, status: :bad_request
    rescue => e
      Rails.logger.error(
        "[DebugReports] failed #{e.class}: #{e.message}"
      )

      if e.backtrace.present?
        Rails.logger.error(e.backtrace.first(10).join("\n"))
      end

      render json: {
        ok: false,
        error: "debug_report_delivery_failed"
      }, status: :internal_server_error
    end

    private

    def rate_limit_allowed?
      ip_digest = Digest::SHA256.hexdigest(request.remote_ip.to_s)
      key = "debug_reports:ip:#{ip_digest}:5m"

      count =
        begin
          Rails.cache.increment(
            key,
            1,
            expires_in: 5.minutes
          )
        rescue
          nil
        end

      # If the current cache store cannot increment,
      # do not break debug reporting entirely.
      #
      # The destination email is fixed server-side,
      # so this endpoint cannot be used as an open mail relay.
      return true if count.nil?

      count <= 5
    end

    def sanitize_value(value, depth = 0)
      return "[TRUNCATED: max depth]" if depth > 12

      case value
      when ActionController::Parameters
        sanitize_value(value.to_unsafe_h, depth + 1)

      when Hash
        output = {}

        value.to_a.first(MAX_HASH_KEYS).each do |key, child|
          clean_key = key.to_s.first(200)

          output[clean_key] =
            if clean_key.match?(SENSITIVE_KEY_PATTERN)
              "[REDACTED]"
            else
              sanitize_value(child, depth + 1)
            end
        end

        if value.size > MAX_HASH_KEYS
          output["_truncated_keys"] =
            value.size - MAX_HASH_KEYS
        end

        output

      when Array
        output =
          value.first(MAX_ARRAY_ITEMS).map do |child|
            sanitize_value(child, depth + 1)
          end

        if value.size > MAX_ARRAY_ITEMS
          output << "[TRUNCATED #{value.size - MAX_ARRAY_ITEMS} ITEMS]"
        end

        output

      when String
        sanitize_string(value)

      when Numeric, TrueClass, FalseClass, NilClass
        value

      else
        sanitize_string(value.to_s)
      end
    end

    def sanitize_string(value)
      text = value.to_s.first(MAX_STRING_LENGTH)

      text =
        text.gsub(
          /Bearer\s+\S+/i,
          "Bearer [REDACTED]"
        )

      text =
        text.gsub(
          JWT_PATTERN,
          "[REDACTED_JWT]"
        )

      text =
        text.gsub(
          /((?:auth|access|refresh|push)[_-]?token|password|secret)=([^&\s]+)/i,
          '\1=[REDACTED]'
        )

      text
    end
  end
end