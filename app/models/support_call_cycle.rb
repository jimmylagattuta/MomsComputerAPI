class SupportCallCycle < ApplicationRecord
  belongs_to :user
  has_many :support_call_sessions, dependent: :destroy

  validates :calls_allowed, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :calls_used, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cycle_start_at, presence: true
  validates :cycle_end_at, presence: true

  scope :current_for_time, ->(time = Time.current) {
    where("cycle_start_at <= ? AND cycle_end_at >= ?", time, time)
  }

  def calls_remaining
    [calls_allowed - calls_used, 0].max
  end

  def has_calls_remaining?
    calls_remaining > 0
  end
end