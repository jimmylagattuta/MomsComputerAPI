class V1::TwilioWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  ANSWERED_STATUSES = %w[in-progress completed].freeze
  NON_CHARGEABLE_FINAL_STATUSES = %w[busy no-answer failed canceled].freeze
  MINIMUM_CHARGEABLE_DURATION_SECONDS = 20

  def voice_bridge
    support_call_session = SupportCallSession.find_by(id: params[:support_call_session_id])

    unless support_call_session
      render plain: "Support call session not found", status: :not_found
      return
    end

    response = Twilio::TwiML::VoiceResponse.new do |r|
      r.say(message: "Connecting you to Mom's Computer support.", voice: "alice")
      r.dial(
        number: ENV.fetch("MOM_SUPPORT_PHONE_NUMBER"),
        answer_on_bridge: true
      )
    end

    render xml: response.to_s
  end

  def call_status
    twilio_call_sid = params[:CallSid]
    call_status = normalize_status(params[:CallStatus])
    duration_seconds = params[:CallDuration].to_i

    support_call_session = SupportCallSession.find_by(twilio_call_sid: twilio_call_sid)

    return head :ok unless support_call_session

    updates = {
      status: map_status(call_status)
    }

    if answered_like_status?(call_status) && support_call_session.answered_at.blank?
      updates[:answered_at] = Time.current
    end

    if terminal_status?(call_status)
      updates[:ended_at] = Time.current
      updates[:duration_seconds] = duration_seconds if duration_seconds.positive?
    end

    if NON_CHARGEABLE_FINAL_STATUSES.include?(call_status)
      updates[:failure_reason] = call_status
    end

    support_call_session.update!(updates)

    if should_mark_chargeable?(support_call_session, call_status, duration_seconds)
      support_call_session.mark_chargeable!(duration: duration_seconds)
    end

    head :ok
  end

  private

  def normalize_status(status)
    status.to_s.strip.downcase
  end

  def map_status(status)
    case status
    when "in-progress"
      "in_progress"
    when "no-answer"
      "no_answer"
    else
      status
    end
  end

  def answered_like_status?(status)
    ANSWERED_STATUSES.include?(status)
  end

  def terminal_status?(status)
    %w[completed busy no-answer failed canceled].include?(status)
  end

  def should_mark_chargeable?(support_call_session, call_status, duration_seconds)
    return false if support_call_session.chargeable?
    return false unless call_status == "completed"
    return false unless duration_seconds >= MINIMUM_CHARGEABLE_DURATION_SECONDS
    return false if support_call_session.buffer_active?

    true
  end
end