class V1::RingcentralWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create], raise: false

  def create
    validation_token = request.headers["Validation-Token"]

    if validation_token.present?
      response.set_header("Validation-Token", validation_token)
    end

    payload = safe_payload

    Rails.logger.info "=============================="
    Rails.logger.info "RINGCENTRAL WEBHOOK HIT"
    Rails.logger.info "Validation Token: #{validation_token}"
    Rails.logger.info "Headers: #{filtered_headers}"
    Rails.logger.info "Payload: #{payload}"
    Rails.logger.info "=============================="

    RingcentralWebhookEvent.create!(
      event_type: extract_event_type(payload),
      telephony_session_id: extract_telephony_session_id(payload),
      party_id: extract_party_id(payload),
      direction: extract_direction(payload),
      status: extract_status(payload),
      caller_phone: extract_caller_phone(payload),
      raw_payload: payload
    )

    render json: {
      ok: true,
      message: "RingCentral webhook received"
    }, status: :ok
  rescue => e
    Rails.logger.error "=============================="
    Rails.logger.error "RINGCENTRAL WEBHOOK ERROR"
    Rails.logger.error "#{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Rails.logger.error "=============================="

    # Important:
    # Return 200 anyway during early webhook testing so RingCentral does not
    # keep retrying while we are still learning the real payload shape.
    render json: {
      ok: false,
      error: e.message
    }, status: :ok
  end

  private

  def safe_payload
    raw_body = request.raw_post

    if raw_body.present?
      JSON.parse(raw_body)
    else
      params.to_unsafe_h
    end
  rescue JSON::ParserError
    params.to_unsafe_h
  end

  def filtered_headers
    request.headers.env.select do |key, _value|
      key.to_s.start_with?("HTTP_") ||
        key.to_s.in?(["CONTENT_TYPE", "CONTENT_LENGTH"])
    end
  end

  def extract_event_type(payload)
    payload["event"] ||
      payload["eventType"] ||
      payload.dig("body", "event") ||
      payload.dig("body", "eventType")
  end

  def extract_telephony_session_id(payload)
    payload.dig("body", "telephonySessionId") ||
      payload.dig("body", "sessionId") ||
      payload["telephonySessionId"] ||
      payload["sessionId"]
  end

  def extract_party_id(payload)
    payload.dig("body", "parties", 0, "id") ||
      payload.dig("body", "partyId") ||
      payload["partyId"]
  end

  def extract_direction(payload)
    payload.dig("body", "parties", 0, "direction") ||
      payload.dig("body", "direction") ||
      payload["direction"]
  end

  def extract_status(payload)
    payload.dig("body", "parties", 0, "status", "code") ||
      payload.dig("body", "parties", 0, "status") ||
      payload.dig("body", "status", "code") ||
      payload.dig("body", "status") ||
      payload["status"]
  end

  def extract_caller_phone(payload)
    payload.dig("body", "parties", 0, "from", "phoneNumber") ||
      payload.dig("body", "from", "phoneNumber") ||
      payload.dig("body", "caller", "phoneNumber") ||
      payload["caller_phone"] ||
      payload["callerPhone"]
  end
end