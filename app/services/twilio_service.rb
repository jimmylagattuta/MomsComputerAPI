class TwilioService
  def self.client
    @client ||= Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )
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