# app/models/revenuecat_customer_link.rb
class RevenuecatCustomerLink < ApplicationRecord
  belongs_to :user, optional: true

  validates :app_user_id, presence: true, uniqueness: true

  scope :linked, -> { where.not(user_id: nil) }
  scope :anonymous, -> { where(user_id: nil) }

  def linked?
    user_id.present?
  end

  def anonymous?
    user_id.blank?
  end
end