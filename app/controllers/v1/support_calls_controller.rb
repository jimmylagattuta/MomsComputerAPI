class V1::SupportCallsController < ApplicationController
  before_action :authenticate_user!

  def create
    user = current_user

    unless user.support_subscription_active?
      return render json: {
        error: "Active subscription required."
      }, status: :forbidden
    end

    cycle = user.current_support_call_cycle

    unless cycle.has_calls_remaining?
      return render json: {
        error: "Monthly call limit reached.",
        calls_remaining: cycle.calls_remaining
      }, status: :forbidden
    end

    user_phone_number = normalized_user_phone_number(user)

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

    twilio_call = TwilioService.start_support_call!(
      support_call_session: support_call_session,
      user_phone_number: user_phone_number
    )

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