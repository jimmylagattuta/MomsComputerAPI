class TwilioService
  def self.client
    @client ||= Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )
  end

  def self.send_sms(to:, body:)
    twilio_debug("Sending SMS", to: to)

    status_callback_url =
      if ENV["APP_BASE_URL"].present?
        "#{ENV.fetch("APP_BASE_URL")}/v1/twilio_webhooks/message_status"
      end

    twilio_debug("SMS status callback URL", url: status_callback_url)

    message = client.messages.create(
      from: ENV.fetch("TWILIO_PHONE_NUMBER"),
      to: to,
      body: body,
      status_callback: status_callback_url
    )

    twilio_debug("SMS sent successfully", sid: message.sid)

    message
  rescue => e
    Rails.logger.error("❌ [Twilio ERROR] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.send_verification_code(to:)
    twilio_debug("Sending verification code", to: to)

    verification = client.verify.v2
      .services(ENV.fetch("TWILIO_VERIFY_SERVICE_SID"))
      .verifications
      .create(
        to: to,
        channel: "sms"
      )

    twilio_debug(
      "Verification started",
      sid: verification.sid,
      status: verification.status
    )

    verification
  rescue => e
    Rails.logger.error("❌ [Twilio Verify ERROR - send_verification_code] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.check_verification_code(to:, code:)
    twilio_debug("Checking verification code", to: to)

    verification_check = client.verify.v2
      .services(ENV.fetch("TWILIO_VERIFY_SERVICE_SID"))
      .verification_checks
      .create(
        to: to,
        code: code
      )

    twilio_debug(
      "Verification check complete",
      sid: verification_check.sid,
      status: verification_check.status
    )

    verification_check
  rescue => e
    Rails.logger.error("❌ [Twilio Verify ERROR - check_verification_code] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.start_support_call!(support_call_session:, user_phone_number:)
    base_url = ENV.fetch("APP_BASE_URL")

    twilio_debug(
      "Starting support call",
      support_call_session_id: support_call_session.id,
      to: user_phone_number
    )

    call = client.calls.create(
      from: ENV.fetch("TWILIO_PHONE_NUMBER"),
      to: user_phone_number,
      url: "#{base_url}/v1/twilio_webhooks/voice_bridge?support_call_session_id=#{support_call_session.id}",
      method: "POST",
      status_callback: "#{base_url}/v1/twilio_webhooks/call_status",
      status_callback_method: "POST",
      status_callback_event: %w[initiated ringing answered completed]
    )

    twilio_debug(
      "Support call started",
      support_call_session_id: support_call_session.id,
      sid: call.sid,
      status: call.status
    )

    call
  rescue => e
    Rails.logger.error("❌ [Twilio Call ERROR - start_support_call] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.twilio_debug(message, data = {})
    return unless ENV["DEBUG_TWILIO"] == "true"

    clean_data = data.compact.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")
    Rails.logger.info("[Twilio] #{message} #{clean_data}".strip)
  end

  private_class_method :twilio_debug
end