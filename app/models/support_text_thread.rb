class SupportTextThread < ApplicationRecord
  STATUSES   = %w[active waiting_on_support waiting_on_user closed blocked].freeze
  PRIORITIES = %w[low normal high urgent].freeze

  belongs_to :user
  belongs_to :support_text_cycle
  has_many :support_text_messages, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :public_token, presence: true, uniqueness: true
  validates :support_identity_label, presence: true

  before_validation :set_defaults, on: :create
  before_validation :ensure_public_token, on: :create

  scope :open_threads, -> { where(status: %w[active waiting_on_support waiting_on_user], blocked: false) }
  scope :active, -> { where(status: %w[active waiting_on_support waiting_on_user], blocked: false) }
  scope :recent_first, -> { order(last_message_at: :desc, updated_at: :desc, id: :desc) }

  def active?
    status.in?(%w[active waiting_on_support waiting_on_user]) && !self[:blocked]
  end

  def waiting_on_support?
    status == "waiting_on_support"
  end

  def waiting_on_user?
    status == "waiting_on_user"
  end

  def closed?
    status == "closed"
  end

  def blocked?
    self[:blocked]
  end

  def cooldown_active?
    cooldown_until.present? && cooldown_until > Time.current
  end

  def mark_waiting_on_support!
    update!(
      status: "waiting_on_support",
      last_user_message_at: Time.current,
      last_message_at: Time.current,
      support_unread: true,
      user_unread: false
    )
  end

  def mark_waiting_on_user!
    update!(
      status: "waiting_on_user",
      last_support_message_at: Time.current,
      last_message_at: Time.current,
      user_unread: true,
      support_unread: false
    )
  end

  def close!
    update!(
      status: "closed",
      closed_at: Time.current,
      user_unread: false,
      support_unread: false
    )
  end

  def block!
    update!(
      status: "blocked",
      blocked: true,
      blocked_at: Time.current,
      closed_at: Time.current,
      user_unread: false,
      support_unread: false
    )
  end

  private

  def set_defaults
    self.status ||= "active"
    self.priority ||= "normal"
    self.intro_sent = false if intro_sent.nil?
    self.blocked = false if self[:blocked].nil?
    self.user_unread = false if user_unread.nil?
    self.support_unread = false if support_unread.nil?
    self.support_identity_snapshot ||= {}
    self.metadata ||= {}
  end

  def ensure_public_token
    return if public_token.present?

    loop do
      self.public_token = "TXT-#{SecureRandom.hex(4).upcase}"
      break unless self.class.exists?(public_token: public_token)
    end
  end
end