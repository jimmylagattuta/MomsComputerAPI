class SupportCallSession < ApplicationRecord
  belongs_to :user
  belongs_to :support_call_cycle

  STATUSES = %w[
    queued
    initiated
    ringing
    in_progress
    completed
    busy
    no_answer
    failed
    canceled
    allowed_pending_forward
    allowed_passthrough
    reconnect_buffer
    forwarded
    blocked
  ].freeze

  RECONNECT_BUFFER_DURATION = 15.minutes

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :twilio_call_sid, uniqueness: true, allow_nil: true

  validates :ringcentral_telephony_session_id,
            uniqueness: {
              scope: :ringcentral_party_id,
              allow_nil: true
            }

  scope :chargeable, -> { where(chargeable: true) }
  scope :not_chargeable, -> { where(chargeable: false) }
  scope :active_buffer, -> { where("buffer_expires_at > ?", Time.current) }
  scope :answered, -> { where.not(answered_at: nil) }
  scope :ended, -> { where.not(ended_at: nil) }
  scope :uncharged, -> { where(charged_at: nil, chargeable: false) }

  def buffer_active?
    buffer_expires_at.present? && buffer_expires_at > Time.current
  end

  def answered?
    answered_at.present?
  end

  def ended?
    ended_at.present?
  end

  def charged?
    chargeable? || charged_at.present?
  end

  def mark_answered!(ringcentral_status: nil)
    update!(
      status: "in_progress",
      answered_at: answered_at || Time.current,
      ringcentral_status: ringcentral_status.presence || self.ringcentral_status
    )
  end

  def mark_ended_and_start_reconnect_buffer!(ringcentral_status: nil)
    update!(
      status: "completed",
      ended_at: ended_at || Time.current,
      ringcentral_status: ringcentral_status.presence || self.ringcentral_status,
      buffer_expires_at: RECONNECT_BUFFER_DURATION.from_now
    )
  end

  def refresh_reconnect_buffer!
    update!(
      buffer_expires_at: RECONNECT_BUFFER_DURATION.from_now
    )
  end

  def schedule_delayed_charge!
    reload

    return false unless answered?
    return false unless ended?
    return false if charged?
    return false unless buffer_expires_at.present?

    SupportCalls::FinalizeAnsweredCallJob
      .set(wait_until: buffer_expires_at)
      .perform_later(id)

    Rails.logger.info(
      "[SupportCallSession] scheduled delayed charge " \
      "session_id=#{id} user_id=#{user_id} " \
      "buffer_expires_at=#{buffer_expires_at}"
    )

    true
  end

  def newer_answered_reconnect_exists?
    return false unless answered_at.present?
    return false unless ended_at.present?

    user.support_call_sessions
      .where(support_call_cycle_id: support_call_cycle_id)
      .where.not(id: id)
      .where.not(answered_at: nil)
      .where.not(ended_at: nil)
      .where("answered_at > ?", answered_at)
      .where("started_at <= ?", buffer_expires_at || Time.current)
      .exists?
  end

  def mark_chargeable!(duration: nil)
    should_sync_ringcentral_block = false
    charge_was_applied = false

    self.class.transaction do
      lock!
      reload

      if charged?
        Rails.logger.info(
          "[SupportCallSession] skipped charge because session is already charged " \
          "session_id=#{id} user_id=#{user_id} charged_at=#{charged_at} chargeable=#{chargeable}"
        )

        return false
      end

      unless answered?
        Rails.logger.info(
          "[SupportCallSession] skipped charge because session was not answered " \
          "session_id=#{id} user_id=#{user_id}"
        )

        return false
      end

      unless ended?
        Rails.logger.info(
          "[SupportCallSession] skipped charge because session has not ended " \
          "session_id=#{id} user_id=#{user_id}"
        )

        return false
      end

      calculated_duration =
        if duration.present?
          duration
        elsif answered_at.present? && ended_at.present?
          [ended_at - answered_at, 0].max.to_i
        else
          0
        end

      cycle = support_call_cycle
      cycle.lock!
      cycle.reload

      update!(
        chargeable: true,
        charged_at: Time.current,
        duration_seconds: calculated_duration
      )

      cycle.increment!(:calls_used)
      cycle.reload

      should_sync_ringcentral_block = cycle.calls_used >= cycle.calls_allowed
      charge_was_applied = true

      Rails.logger.info(
        "[SupportCallSession] charged answered call " \
        "session_id=#{id} user_id=#{user_id} cycle_id=#{cycle.id} " \
        "calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed} " \
        "duration_seconds=#{calculated_duration}"
      )
    end

    sync_ringcentral_blocked_status! if charge_was_applied && should_sync_ringcentral_block

    charge_was_applied
  end

  private

  def sync_ringcentral_blocked_status!
    return if user.phone.blank?

    result = Ringcentral::SyncBlockedCaller.call(user)

    Rails.logger.info(
      "[SupportCallSession] RingCentral block sync after charge " \
      "session_id=#{id} user_id=#{user.id} result=#{result.inspect}"
    )

    result
  rescue StandardError => e
    Rails.logger.error(
      "[SupportCallSession] RingCentral block sync failed " \
      "session_id=#{id} user_id=#{user.id} #{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    nil
  end
end