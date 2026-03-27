# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_one :user_profile, dependent: :destroy
  has_many :devices, -> { order(last_seen_at: :desc) }, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :trusted_contacts, dependent: :destroy
  has_many :escalation_tickets, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :entitlements, dependent: :destroy
  has_many :consent_records, dependent: :destroy
  has_many :support_call_cycles, dependent: :destroy
  has_many :support_call_sessions, dependent: :destroy
  has_many :support_text_cycles, dependent: :destroy
  has_many :support_text_threads, dependent: :destroy
  has_many :support_text_messages, dependent: :nullify

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  def current_support_call_cycle(time = Time.current)
    SupportCallCycleService.current_cycle_for(self, time)
  end

  def support_calls_remaining(time = Time.current)
    current_support_call_cycle(time).calls_remaining
  end

  def support_subscription_active?
    subscriptions.where(status: "active").exists?
  end

  def active_devices
    devices.where("last_seen_at > ?", 30.days.ago)
  end

  def admin?
    role == "admin"
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end