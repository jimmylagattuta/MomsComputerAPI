# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_one :user_profile, dependent: :destroy
  has_many :devices, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :trusted_contacts, dependent: :destroy
  has_many :escalation_tickets, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :entitlements, dependent: :destroy
  has_many :consent_records, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end