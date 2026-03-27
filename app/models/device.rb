class Device < ApplicationRecord
  belongs_to :user

  validates :platform, presence: true
  validates :device_name, presence: true

  # Optional but recommended: ensure push tokens are unique per device
  validates :push_token, uniqueness: true, allow_nil: true

  # Optional: scope for active devices
  scope :active, -> { where("devices.last_seen_at > ?", 30.days.ago) }
end