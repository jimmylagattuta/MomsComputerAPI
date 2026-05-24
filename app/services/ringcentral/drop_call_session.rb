# app/services/ringcentral/drop_call_session.rb

require "ringcentral"

module Ringcentral
  class DropCallSession
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      return failure!("missing_telephony_session_id") if event.telephony_session_id.blank?

      Rails.logger.info(
        "[RingCentral Drop Session] Starting " \
        "event_id=#{event.id} " \
        "telephony_session_id=#{event.telephony_session_id} " \
        "party_id=#{event.party_id} " \
        "caller_phone=#{event.caller_phone}"
      )

      rc = RingCentral.new(
        ENV.fetch("RINGCENTRAL_CLIENT_ID"),
        ENV.fetch("RINGCENTRAL_CLIENT_SECRET"),
        ENV.fetch("RINGCENTRAL_SERVER_URL")
      )

      rc.authorize(jwt: ENV.fetch("RINGCENTRAL_JWT"))

      path = "/restapi/v1.0/account/~/telephony/sessions/#{event.telephony_session_id}"

      response = rc.delete(path)

      Rails.logger.info(
        "[RingCentral Drop Session] Success " \
        "event_id=#{event.id} response=#{response.body.inspect}"
      )

      {
        success: true,
        response: response.body
      }
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Drop Session] FAILED " \
        "event_id=#{event.id} #{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :event

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Drop Session] Cannot drop call session " \
        "event_id=#{event.id} reason=#{reason}"
      )

      {
        success: false,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end