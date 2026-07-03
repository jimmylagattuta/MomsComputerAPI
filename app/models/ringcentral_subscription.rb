class RingcentralSubscription < ApplicationRecord
  validates :subscription_id, presence: true, uniqueness: true

  scope :active, -> { where(status: "Active") }
  scope :for_delivery_address, ->(address) { where(delivery_address: address) }

  def expired?
    expiration_time.present? && expiration_time <= Time.current
  end

  def expires_within?(duration)
    expiration_time.present? && expiration_time <= duration.from_now
  end
end
