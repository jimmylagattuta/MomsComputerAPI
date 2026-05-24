# app/services/ringcentral/block_phone_number.rb

require "ringcentral"

module Ringcentral
  class BlockPhoneNumber
    DEFAULT_LABEL = "Mom's Computer app monthly call limit".freeze

    def self.call(phone, label: DEFAULT_LABEL)
      new(phone, label: label).call
    end

    def initialize(phone, label:)
      @phone = phone
      @label = label
    end

    def call
      normalized_phone = normalize_phone(phone)

      return failure!("missing_phone") if normalized_phone.blank?

      Rails.logger.info(
        "[RingCentral Block Number] Starting phone=#{normalized_phone} " \
        "extension_id=#{blocking_extension_id}"
      )

      existing_record = existing_blocked_record(normalized_phone)

      if existing_record.present?
        Rails.logger.info(
          "[RingCentral Block Number] Already blocked " \
          "phone=#{normalized_phone} record=#{existing_record.inspect}"
        )

        return {
          success: true,
          already_blocked: true,
          phone: normalized_phone,
          record: existing_record
        }
      end

      payload = {
        phoneNumber: normalized_phone,
        label: label,
        status: "Blocked"
      }

      response = rc_client.post(blocked_allowed_numbers_path, payload: payload)

      Rails.logger.info(
        "[RingCentral Block Number] Success phone=#{normalized_phone} " \
        "response=#{response.body.inspect}"
      )

      {
        success: true,
        already_blocked: false,
        phone: normalized_phone,
        response: response.body
      }
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Block Number] FAILED phone=#{phone.inspect} " \
        "#{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        phone: phone,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :phone, :label

    def rc_client
      @rc_client ||= begin
        rc = RingCentral.new(
          ENV.fetch("RINGCENTRAL_CLIENT_ID"),
          ENV.fetch("RINGCENTRAL_CLIENT_SECRET"),
          ENV.fetch("RINGCENTRAL_SERVER_URL")
        )

        rc.authorize(jwt: ENV.fetch("RINGCENTRAL_JWT"))
        rc
      end
    end

    def blocking_extension_id
      ENV.fetch("RINGCENTRAL_BLOCKING_EXTENSION_ID", "~")
    end

    def blocked_allowed_numbers_path
      "/restapi/v1.0/account/~/extension/#{blocking_extension_id}/blocked-allowed-numbers"
    end

    def existing_blocked_record(normalized_phone)
      response = rc_client.get(blocked_allowed_numbers_path)
      records = response.body["records"] || []

      records.find do |record|
        normalize_phone(record["phoneNumber"]) == normalized_phone &&
          record["status"].to_s.downcase == "blocked"
      end
    end

    def normalize_phone(value)
      raw = value.to_s.strip
      digits = raw.gsub(/\D/, "")

      return nil if digits.blank?

      last_10 = digits.last(10)

      return nil if last_10.blank? || last_10.length < 10

      "+1#{last_10}"
    end

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Block Number] Cannot block phone=#{phone.inspect} reason=#{reason}"
      )

      {
        success: false,
        phone: phone,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end