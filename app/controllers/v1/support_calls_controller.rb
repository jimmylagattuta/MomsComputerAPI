class V1::SupportCallsController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!

  def create
    user = current_user

    cycle = user.current_support_call_cycle

    unless cycle.has_calls_remaining?
      return render json: {
        error: "Monthly call limit reached.",
        calls_remaining: cycle.calls_remaining
      }, status: :forbidden
    end

    user_phone_number = normalized_user_phone_number(user)

    Rails.logger.info("📞 [SUPPORT CALL] user_id=#{user.id} user_phone_number=#{user_phone_number.inspect}")

    if user_phone_number.blank?
      return render json: {
        error: "User phone number is missing."
      }, status: :unprocessable_entity
    end

    support_call_session = user.support_call_sessions.create!(
      support_call_cycle: cycle,
      status: "queued",
      started_at: Time.current,
      chargeable: false
    )

    Rails.logger.info("📞 [SUPPORT CALL] session_created id=#{support_call_session.id}")

    twilio_call = TwilioService.start_support_call!(
      support_call_session: support_call_session,
      user_phone_number: user_phone_number
    )

    Rails.logger.info("📞 [SUPPORT CALL] twilio_call_created sid=#{twilio_call.sid} status=#{twilio_call.status.inspect}")

    support_call_session.update!(
      twilio_call_sid: twilio_call.sid,
      status: twilio_call.status.presence || "initiated"
    )

    render json: {
      success: true,
      message: "Support call started.",
      support_call_session_id: support_call_session.id,
      calls_remaining: cycle.calls_remaining
    }, status: :created
  rescue Twilio::REST::RestError => e
    Rails.logger.error("Twilio support call error: #{e.message}")

    render json: {
      error: "Unable to start support call."
    }, status: :unprocessable_entity
  end

  private

  def normalized_user_phone_number(user)
    user.phone_number.presence || user.phone.presence
  end
end