# app/services/ringcentral/forward_call_party.rb

require "ringcentral"

module Ringcentral
  class ForwardCallParty
    DEFAULT_DESTINATION = "+13109283223"

    def self.call(event, destination_phone: nil)
      new(event, destination_phone: destination_phone).call
    end

    def initialize(event, destination_phone: nil)
      @event = event
      @destination_phone =
        normalize_phone(
          destination_phone.presence ||
          ENV.fetch(
            "RINGCENTRAL_ALLO_FORWARD_NUMBER",
            DEFAULT_DESTINATION
          )
        )
    end

    def call
      return failure!("missing_telephony_session_id") if event.telephony_session_id.blank?
      return failure!("missing_party_id") if event.party_id.blank?
      return failure!("missing_destination_phone") if destination_phone.blank?

      unless ["Setup", "Proceeding"].include?(event.status)
        return failure!("call_not_forwardable_status_#{event.status}")
      end

      Rails.logger.info(
        "[RingCentral Forward] Starting " \
        "event_id=#{event.id} " \
        "telephony_session_id=#{event.telephony_session_id} " \
        "party_id=#{event.party_id} " \
        "caller_phone=#{event.caller_phone} " \
        "to_phone=#{event.to_phone} " \
        "destination_phone=#{destination_phone}"
      )

      rc = RingCentral.new(
        ENV.fetch("RINGCENTRAL_CLIENT_ID"),
        ENV.fetch("RINGCENTRAL_CLIENT_SECRET"),
        ENV.fetch("RINGCENTRAL_SERVER_URL")
      )

      rc.authorize(jwt: ENV.fetch("RINGCENTRAL_JWT"))

      path =
        "/restapi/v1.0/account/~/telephony/sessions/" \
        "#{event.telephony_session_id}/parties/#{event.party_id}/forward"

      response = rc.post(
        path,
        payload: {
          phoneNumber: destination_phone
        }
      )

      Rails.logger.info(
        "[RingCentral Forward] Success " \
        "event_id=#{event.id} " \
        "destination_phone=#{destination_phone} " \
        "response=#{response.body.inspect}"
      )

      {
        success: true,
        destination_phone: destination_phone,
        response: response.body
      }
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Forward] FAILED " \
        "event_id=#{event.id} " \
        "destination_phone=#{destination_phone.inspect} " \
        "#{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        destination_phone: destination_phone,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :event, :destination_phone

    def normalize_phone(value)
      raw = value.to_s.strip
      digits = raw.gsub(/\D/, "")

      return nil if digits.blank?

      if digits.length == 10
        "+1#{digits}"
      elsif digits.length == 11 && digits.start_with?("1")
        "+#{digits}"
      else
        "+#{digits}"
      end
    end

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Forward] Cannot forward call " \
        "event_id=#{event.id} " \
        "destination_phone=#{destination_phone.inspect} " \
        "reason=#{reason}"
      )

      {
        success: false,
        destination_phone: destination_phone,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end