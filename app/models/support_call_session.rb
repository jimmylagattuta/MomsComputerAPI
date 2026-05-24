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
    forwarded
    blocked
  ].freeze

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

  RECONNECT_BUFFER_DURATION = 15.minutes

  def buffer_active?
    buffer_expires_at.present? && buffer_expires_at > Time.current
  end

  def mark_chargeable!(duration:)
    should_sync_ringcentral_block = false

    transaction do
      return if chargeable?

      update!(
        chargeable: true,
        charged_at: Time.current,
        duration_seconds: duration,
        buffer_expires_at: RECONNECT_BUFFER_DURATION.from_now
      )

      support_call_cycle.increment!(:calls_used)
      support_call_cycle.reload

      should_sync_ringcentral_block = support_call_cycle.calls_used >= support_call_cycle.calls_allowed
    end

    sync_ringcentral_blocked_status! if should_sync_ringcentral_block
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