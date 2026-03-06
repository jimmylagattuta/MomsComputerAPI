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
  ].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :twilio_call_sid, uniqueness: true, allow_nil: true

  scope :chargeable, -> { where(chargeable: true) }
  scope :not_chargeable, -> { where(chargeable: false) }
  scope :active_buffer, -> { where("buffer_expires_at > ?", Time.current) }

  RECONNECT_BUFFER_DURATION = 15.minutes

  def buffer_active?
    buffer_expires_at.present? && buffer_expires_at > Time.current
  end

  def mark_chargeable!(duration:)
    return if chargeable?

    transaction do
      update!(
        chargeable: true,
        charged_at: Time.current,
        duration_seconds: duration,
        buffer_expires_at: RECONNECT_BUFFER_DURATION.from_now
      )

      support_call_cycle.increment!(:calls_used)
    end
  end
end