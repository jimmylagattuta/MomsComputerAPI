# app/services/ringcentral/unblock_phone_number.rb

require "ringcentral"

module Ringcentral
  class UnblockPhoneNumber
    def self.call(phone)
      new(phone).call
    end

    def initialize(phone)
      @phone = phone
    end

    def call
      normalized_phone = normalize_phone(phone)

      return failure!("missing_phone") if normalized_phone.blank?

      Rails.logger.info(
        "[RingCentral Unblock Number] Starting phone=#{normalized_phone} " \
        "extension_id=#{blocking_extension_id} path=#{caller_blocking_phone_numbers_path}"
      )

      records = matching_blocked_records(normalized_phone)

      if records.empty?
        Rails.logger.info(
          "[RingCentral Unblock Number] No blocked records found phone=#{normalized_phone}"
        )

        return {
          success: true,
          already_unblocked: true,
          phone: normalized_phone,
          deleted_count: 0
        }
      end

      deleted = []

      records.each do |record|
        record_id = record["id"]

        next if record_id.blank?

        response = rc_client.delete("#{caller_blocking_phone_numbers_path}/#{record_id}")

        deleted << {
          id: record_id,
          response: response.body
        }
      end

      Rails.logger.info(
        "[RingCentral Unblock Number] Success phone=#{normalized_phone} " \
        "deleted_count=#{deleted.length}"
      )

      {
        success: true,
        already_unblocked: false,
        phone: normalized_phone,
        deleted_count: deleted.length,
        deleted: deleted
      }
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Unblock Number] FAILED phone=#{phone.inspect} " \
        "extension_id=#{blocking_extension_id} #{e.class}: #{e.message}"
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

    attr_reader :phone

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

    def caller_blocking_phone_numbers_path
      "/restapi/v1.0/account/~/extension/#{blocking_extension_id}/caller-blocking/phone-numbers"
    end

    def matching_blocked_records(normalized_phone)
      response = rc_client.get(caller_blocking_phone_numbers_path)
      records = response.body["records"] || []

      records.select do |record|
        normalize_phone(record["phoneNumber"]) == normalized_phone
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
        "[RingCentral Unblock Number] Cannot unblock phone=#{phone.inspect} reason=#{reason}"
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