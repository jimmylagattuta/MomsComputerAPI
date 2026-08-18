# app/services/revenuecat/customer_status_fetcher.rb

require "net/http"
require "uri"
require "json"
require "time"

module Revenuecat
  class CustomerStatusFetcher
    API_BASE_URL = "https://api.revenuecat.com"
    API_VERSION_PATH = "/v1"

    DEFAULT_PREMIUM_ENTITLEMENT_KEYS = [
      "pro",
      "Mom’s Computer Pro",
      "Mom's Computer Pro",
      "premium"
    ].freeze

    Result = Struct.new(
      :active,
      :entitlement_key,
      :product_id,
      :expires_at,
      :original_app_user_id,
      :store,
      :environment,
      :raw,
      keyword_init: true
    ) do
      def active?
        active == true
      end
    end

    def initialize(app_user_id:)
      @app_user_id = app_user_id.to_s.strip
    end

    def call
      return inactive_result(reason: "missing_app_user_id") if @app_user_id.blank?

      api_key = revenuecat_api_key

      if api_key.blank?
        debug_log("missing_api_key", {
          app_user_id: @app_user_id,
          checked_env_keys: revenuecat_api_key_env_names
        })

        return inactive_result(reason: "missing_revenuecat_api_key")
      end

      debug_log("start", {
        app_user_id: @app_user_id,
        api_base_url: API_BASE_URL,
        entitlement_keys_expected: premium_entitlement_keys,
        api_key_present: true,
        api_key_prefix: safe_key_prefix(api_key)
      })

      response = fetch_customer(api_key)

      unless response.is_a?(Net::HTTPSuccess)
        debug_log("http_error", {
          app_user_id: @app_user_id,
          status: response.code.to_i,
          body: safe_response_summary(response.body)
        })

        return inactive_result(
          reason: "revenuecat_http_error",
          raw: {
            status: response.code.to_i,
            body: safe_response_summary(response.body)
          }
        )
      end

      payload = parse_json(response.body)

      unless payload.is_a?(Hash)
        debug_log("invalid_json_response", {
          app_user_id: @app_user_id,
          status: response.code.to_i,
          body: safe_response_summary(response.body)
        })

        return inactive_result(
          reason: "invalid_revenuecat_response"
        )
      end

      subscriber = payload["subscriber"] || {}

      debug_customer_payload(subscriber, response.code.to_i)

      result = result_from_subscriber(subscriber)

      debug_log("result", {
        app_user_id: @app_user_id,
        active: result.active?,
        entitlement_key: result.entitlement_key,
        product_id: result.product_id,
        expires_at: result.expires_at,
        original_app_user_id: result.original_app_user_id,
        store: result.store,
        environment: result.environment
      })

      result
    rescue Timeout::Error => e
      Rails.logger.error(
        "[RC_STATUS] timeout app_user_id=#{@app_user_id.inspect} " \
        "#{e.class}: #{e.message}"
      )

      inactive_result(reason: "revenuecat_timeout")
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
      Rails.logger.error(
        "[RC_STATUS] network_error app_user_id=#{@app_user_id.inspect} " \
        "#{e.class}: #{e.message}"
      )

      inactive_result(reason: "revenuecat_network_error")
    rescue => e
      Rails.logger.error(
        "[RC_STATUS] failed app_user_id=#{@app_user_id.inspect} " \
        "#{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(20).join("\n"))

      inactive_result(
        reason: "revenuecat_status_fetch_failed",
        raw: {
          error_class: e.class.name,
          error: e.message
        }
      )
    end

    private

    def fetch_customer(api_key)
      encoded_app_user_id = URI.encode_www_form_component(@app_user_id)

      uri = URI.parse(
        "#{API_BASE_URL}#{API_VERSION_PATH}/subscribers/#{encoded_app_user_id}"
      )

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"

      debug_log("request", {
        method: "GET",
        url: "#{API_BASE_URL}#{API_VERSION_PATH}/subscribers/[APP_USER_ID]",
        app_user_id: @app_user_id
      })

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 8,
        read_timeout: 12
      ) do |http|
        response = http.request(request)

        debug_log("response", {
          app_user_id: @app_user_id,
          status: response.code.to_i,
          success: response.is_a?(Net::HTTPSuccess)
        })

        response
      end
    end

    def result_from_subscriber(subscriber)
      entitlements = subscriber["entitlements"]
      entitlements = {} unless entitlements.is_a?(Hash)

      subscriptions = subscriber["subscriptions"]
      subscriptions = {} unless subscriptions.is_a?(Hash)

      active_entitlements = entitlements.each_with_object([]) do |(key, data), rows|
        next unless data.is_a?(Hash)

        expires_at = parse_time(data["expires_date"])

        active =
          data["expires_date"].blank? ||
          (expires_at.present? && expires_at.future?)

        next unless active

        product_id = data["product_identifier"].presence

        subscription_data =
          product_id.present? && subscriptions[product_id].is_a?(Hash) ?
            subscriptions[product_id] :
            {}

        rows << {
          key: key.to_s,
          product_id: product_id,
          expires_at: expires_at,
          store: subscription_data["store"],
          is_sandbox: subscription_data["is_sandbox"],
          purchase_date: data["purchase_date"],
          raw_entitlement: data,
          raw_subscription: subscription_data
        }
      end

      debug_log("active_entitlements", {
        app_user_id: @app_user_id,
        count: active_entitlements.length,
        entries: active_entitlements.map do |entry|
          {
            key: entry[:key],
            product_id: entry[:product_id],
            expires_at: entry[:expires_at],
            store: entry[:store],
            is_sandbox: entry[:is_sandbox]
          }
        end
      })

      selected = select_premium_entitlement(active_entitlements)

      unless selected
        return Result.new(
          active: false,
          entitlement_key: nil,
          product_id: nil,
          expires_at: nil,
          original_app_user_id: subscriber["original_app_user_id"],
          store: nil,
          environment: nil,
          raw: {
            reason: "no_active_premium_entitlement",
            active_entitlement_keys: active_entitlements.map { |entry| entry[:key] },
            entitlement_keys_expected: premium_entitlement_keys
          }
        )
      end

      environment =
        if selected[:is_sandbox] == true
          "sandbox"
        elsif selected[:is_sandbox] == false
          "production"
        end

      Result.new(
        active: true,
        entitlement_key: selected[:key],
        product_id: selected[:product_id],
        expires_at: selected[:expires_at],
        original_app_user_id: subscriber["original_app_user_id"],
        store: selected[:store],
        environment: environment,
        raw: {
          reason: "active_premium_entitlement",
          active_entitlement_keys: active_entitlements.map { |entry| entry[:key] },
          selected_entitlement: {
            key: selected[:key],
            product_id: selected[:product_id],
            expires_at: selected[:expires_at],
            store: selected[:store],
            is_sandbox: selected[:is_sandbox]
          }
        }
      )
    end

    def select_premium_entitlement(active_entitlements)
      return nil if active_entitlements.empty?

      normalized_expected = premium_entitlement_keys.map do |key|
        normalize_entitlement_key(key)
      end

      expected_match = active_entitlements.find do |entry|
        normalized_expected.include?(
          normalize_entitlement_key(entry[:key])
        )
      end

      if expected_match
        debug_log("premium_entitlement_match", {
          app_user_id: @app_user_id,
          match_type: "expected_key",
          entitlement_key: expected_match[:key],
          product_id: expected_match[:product_id]
        })

        return expected_match
      end

      # Your current mobile app treats any active RevenueCat entitlement as
      # Premium (`isProActive(...) || activeKeys.length > 0`).
      #
      # Keep the backend behavior aligned with that existing app behavior.
      fallback = active_entitlements.first

      debug_log("premium_entitlement_match", {
        app_user_id: @app_user_id,
        match_type: "fallback_any_active_entitlement",
        entitlement_key: fallback[:key],
        product_id: fallback[:product_id],
        warning: "No configured premium entitlement key matched; using first active entitlement."
      })

      fallback
    end

    def premium_entitlement_keys
      configured = ENV["REVENUECAT_PREMIUM_ENTITLEMENTS"].to_s
        .split(",")
        .map(&:strip)
        .reject(&:blank?)

      (configured + DEFAULT_PREMIUM_ENTITLEMENT_KEYS).uniq
    end

    def normalize_entitlement_key(value)
      value
        .to_s
        .unicode_normalize(:nfkc)
        .tr("’", "'")
        .strip
        .downcase
    rescue
      value.to_s.strip.downcase
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def revenuecat_api_key
      revenuecat_api_key_env_names.each do |name|
        value = ENV[name].to_s.strip
        return value if value.present?
      end

      nil
    end

    def revenuecat_api_key_env_names
      [
        "REVENUECAT_SECRET_API_KEY",
        "REVENUECAT_API_KEY",
        "RC_SECRET_API_KEY",
        "REVENUECAT_SECRET_KEY"
      ]
    end

    def inactive_result(reason:, raw: nil)
      Result.new(
        active: false,
        entitlement_key: nil,
        product_id: nil,
        expires_at: nil,
        original_app_user_id: nil,
        store: nil,
        environment: nil,
        raw: {
          reason: reason,
          details: raw
        }.compact
      )
    end

    def parse_json(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      nil
    end

    def debug_customer_payload(subscriber, status)
      entitlements = subscriber["entitlements"]
      entitlements = {} unless entitlements.is_a?(Hash)

      subscriptions = subscriber["subscriptions"]
      subscriptions = {} unless subscriptions.is_a?(Hash)

      debug_log("customer", {
        app_user_id: @app_user_id,
        http_status: status,
        original_app_user_id: subscriber["original_app_user_id"],
        entitlement_keys: entitlements.keys,
        entitlements: entitlements.map do |key, data|
          {
            key: key,
            product_identifier: data.is_a?(Hash) ? data["product_identifier"] : nil,
            expires_date: data.is_a?(Hash) ? data["expires_date"] : nil,
            purchase_date: data.is_a?(Hash) ? data["purchase_date"] : nil
          }
        end,
        subscription_product_ids: subscriptions.keys,
        subscriptions: subscriptions.map do |product_id, data|
          {
            product_id: product_id,
            expires_date: data.is_a?(Hash) ? data["expires_date"] : nil,
            grace_period_expires_date:
              data.is_a?(Hash) ? data["grace_period_expires_date"] : nil,
            store: data.is_a?(Hash) ? data["store"] : nil,
            is_sandbox: data.is_a?(Hash) ? data["is_sandbox"] : nil,
            period_type: data.is_a?(Hash) ? data["period_type"] : nil,
            billing_issues_detected_at:
              data.is_a?(Hash) ? data["billing_issues_detected_at"] : nil,
            unsubscribe_detected_at:
              data.is_a?(Hash) ? data["unsubscribe_detected_at"] : nil
          }
        end
      })
    end

    def safe_response_summary(body)
      parsed = parse_json(body)

      if parsed.is_a?(Hash)
        {
          code: parsed["code"],
          message: parsed["message"],
          error: parsed["error"]
        }.compact
      else
        body.to_s[0, 300]
      end
    end

    def safe_key_prefix(key)
      value = key.to_s
      return nil if value.blank?

      if value.length <= 8
        "[present]"
      else
        "#{value[0, 4]}…#{value[-4, 4]}"
      end
    end

    def debug_log(event, payload = {})
      return unless ENV["DEBUG_RC_LINK"] == "true"

      Rails.logger.info("[RC_STATUS] #{event} #{payload.to_json}")
    end
  end
end