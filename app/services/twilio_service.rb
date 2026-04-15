class TwilioService
  def self.client
    @client ||= Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )
  end

  def self.send_sms(to:, body:)
    Rails.logger.info("📲 [Twilio] Sending SMS to #{to}")

    status_callback_url =
      if ENV["APP_BASE_URL"].present?
        "#{ENV.fetch("APP_BASE_URL")}/v1/twilio_webhooks/message_status"
      end

    Rails.logger.info("🔗 [Twilio] SMS status callback URL=#{status_callback_url.inspect}")

    message = client.messages.create(
      from: ENV.fetch("TWILIO_PHONE_NUMBER"),
      to: to,
      body: body,
      status_callback: status_callback_url
    )

    Rails.logger.info("✅ [Twilio] Sent successfully SID=#{message.sid}")
    message
  rescue => e
    Rails.logger.error("❌ [Twilio ERROR] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.send_verification_code(to:)
    Rails.logger.info("📲 [Twilio Verify] Sending verification code to #{to}")

    verification = client.verify.v2
      .services(ENV.fetch("TWILIO_VERIFY_SERVICE_SID"))
      .verifications
      .create(
        to: to,
        channel: "sms"
      )

    Rails.logger.info("✅ [Twilio Verify] Verification started SID=#{verification.sid} status=#{verification.status}")
    verification
  rescue => e
    Rails.logger.error("❌ [Twilio Verify ERROR - send_verification_code] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.check_verification_code(to:, code:)
    Rails.logger.info("🔍 [Twilio Verify] Checking verification code for #{to}")

    verification_check = client.verify.v2
      .services(ENV.fetch("TWILIO_VERIFY_SERVICE_SID"))
      .verification_checks
      .create(
        to: to,
        code: code
      )

    Rails.logger.info("✅ [Twilio Verify] Check complete SID=#{verification_check.sid} status=#{verification_check.status}")
    verification_check
  rescue => e
    Rails.logger.error("❌ [Twilio Verify ERROR - check_verification_code] #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
    raise e
  end

  def self.start_support_call!(support_call_session:, user_phone_number:)
    base_url = ENV.fetch("APP_BASE_URL")

    client.calls.create(
      from: ENV.fetch("TWILIO_PHONE_NUMBER"),
      to: user_phone_number,
      url: "#{base_url}/v1/twilio_webhooks/voice_bridge?support_call_session_id=#{support_call_session.id}",
      method: "POST",
      status_callback: "#{base_url}/v1/twilio_webhooks/call_status",
      status_callback_method: "POST",
      status_callback_event: %w[initiated ringing answered completed]
    )
  end
end