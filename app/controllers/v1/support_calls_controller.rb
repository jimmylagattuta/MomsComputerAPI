class V1::SupportCallsController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!

  RINGCENTRAL_SUPPORT_NUMBER = ENV.fetch("RINGCENTRAL_SUPPORT_NUMBER", "+18002810692")

  def create
    user = current_user
    cycle = user.current_support_call_cycle

    active_buffer_session = active_reconnect_buffer_session_for(user)

    if active_buffer_session.present?
      Rails.logger.info(
        "📞 [SUPPORT CALL] active reconnect buffer found " \
        "user_id=#{user.id} session_id=#{active_buffer_session.id} " \
        "buffer_expires_at=#{active_buffer_session.buffer_expires_at}"
      )
    elsif !cycle.has_calls_remaining?
      sync_ringcentral_block_for_user(user)

      Rails.logger.info(
        "📞 [SUPPORT CALL] blocked monthly limit reached " \
        "user_id=#{user.id} calls_used=#{cycle.calls_used} " \
        "calls_allowed=#{cycle.calls_allowed} calls_remaining=#{cycle.calls_remaining}"
      )

      return render json: {
        success: false,
        error: "Monthly call limit reached.",
        call_number: nil,
        calls_allowed: cycle.calls_allowed,
        calls_used: cycle.calls_used,
        calls_remaining: cycle.calls_remaining,
        reconnect_buffer_active: false,
        buffer_expires_at: nil,
        renews_at: cycle.cycle_end_at
      }, status: :forbidden
    end

    user_phone_number = normalized_user_phone_number(user)

    Rails.logger.info(
      "📞 [SUPPORT CALL] authorization requested " \
      "user_id=#{user.id} user_phone_number=#{user_phone_number.inspect} " \
      "calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed} " \
      "calls_remaining=#{cycle.calls_remaining} reconnect_buffer=#{active_buffer_session.present?}"
    )

    if user_phone_number.blank?
      return render json: {
        success: false,
        error: "User phone number is missing.",
        call_number: nil,
        calls_allowed: cycle.calls_allowed,
        calls_used: cycle.calls_used,
        calls_remaining: cycle.calls_remaining,
        reconnect_buffer_active: active_buffer_session.present?,
        buffer_expires_at: active_buffer_session&.buffer_expires_at,
        renews_at: cycle.cycle_end_at
      }, status: :unprocessable_entity
    end

    sync_ringcentral_allow_for_user(user)

    support_call_session = user.support_call_sessions.create!(
      support_call_cycle: cycle,
      status: active_buffer_session.present? ? "reconnect_buffer" : "allowed_pending_forward",
      started_at: Time.current,
      chargeable: false,
      buffer_expires_at: active_buffer_session&.buffer_expires_at,
      caller_phone: user_phone_number,
      to_phone: RINGCENTRAL_SUPPORT_NUMBER
    )

    Rails.logger.info(
      "📞 [SUPPORT CALL] authorization session created " \
      "session_id=#{support_call_session.id} user_id=#{user.id} " \
      "status=#{support_call_session.status} reconnect_buffer=#{active_buffer_session.present?} " \
      "call_number=#{RINGCENTRAL_SUPPORT_NUMBER}"
    )

    render json: {
      success: true,
      message: authorization_message(cycle, active_buffer_session),
      call_number: RINGCENTRAL_SUPPORT_NUMBER,
      support_call_session_id: support_call_session.id,
      calls_allowed: cycle.calls_allowed,
      calls_used: cycle.calls_used,
      calls_remaining: cycle.calls_remaining,
      reconnect_buffer_active: active_buffer_session.present?,
      buffer_expires_at: active_buffer_session&.buffer_expires_at,
      renews_at: cycle.cycle_end_at
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error(
      "📞 [SUPPORT CALL] authorization error " \
      "#{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    render json: {
      success: false,
      error: "Unable to authorize support call."
    }, status: :unprocessable_entity
  end

  private

  def active_reconnect_buffer_session_for(user)
    user.support_call_sessions
      .where("buffer_expires_at > ?", Time.current)
      .order(buffer_expires_at: :desc)
      .first
  end

  def authorization_message(cycle, active_buffer_session)
    if active_buffer_session.present?
      "Reconnect window active. This call will not count as a new monthly call if it connects during the buffer."
    elsif cycle.calls_remaining == 1
      "You have 1 support call remaining this month."
    else
      "You have #{cycle.calls_remaining} support calls remaining this month."
    end
  end

  def normalized_user_phone_number(user)
    user.phone.to_s.strip.presence
  end

  def sync_ringcentral_allow_for_user(user)
    return if normalized_user_phone_number(user).blank?

    result = Ringcentral::SyncAllowedCaller.call(user)

    Rails.logger.info(
      "📞 [SUPPORT CALL] RingCentral allow sync complete " \
      "user_id=#{user.id} result=#{result.inspect}"
    )

    result
  rescue StandardError => e
    Rails.logger.error(
      "📞 [SUPPORT CALL] RingCentral allow sync failed " \
      "user_id=#{user.id} #{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    nil
  end

  def sync_ringcentral_block_for_user(user)
    return if normalized_user_phone_number(user).blank?

    result = Ringcentral::SyncBlockedCaller.call(user)

    Rails.logger.info(
      "📞 [SUPPORT CALL] RingCentral block sync complete " \
      "user_id=#{user.id} result=#{result.inspect}"
    )

    result
  rescue StandardError => e
    Rails.logger.error(
      "📞 [SUPPORT CALL] RingCentral block sync failed " \
      "user_id=#{user.id} #{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    nil
  end
end