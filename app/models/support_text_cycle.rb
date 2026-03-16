class SupportTextCycle < ApplicationRecord
  belongs_to :user
  has_many :support_text_threads, dependent: :destroy

  validates :messages_used, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :images_used, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cycle_start_at, :cycle_end_at, presence: true
  validate :cycle_range_is_valid

  scope :current_for_time, ->(time = Time.current) {
    where("cycle_start_at <= ? AND cycle_end_at >= ?", time, time)
  }

  scope :recent_first, -> { order(cycle_start_at: :desc, id: :desc) }

  def self.current_or_create_for!(user, now: Time.current)
    existing = current_for_time(now).find_by(user_id: user.id)
    return existing if existing

    create!(
      user: user,
      cycle_start_at: now.beginning_of_month,
      cycle_end_at: now.end_of_month,
      messages_used: 0,
      images_used: 0
    )
  end

  def current?(time = Time.current)
    cycle_start_at <= time && cycle_end_at >= time
  end

  private

  def cycle_range_is_valid
    return if cycle_start_at.blank? || cycle_end_at.blank?
    return if cycle_end_at >= cycle_start_at

    errors.add(:cycle_end_at, "must be after or equal to cycle_start_at")
  end
end