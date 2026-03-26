class SupportTextMessage < ApplicationRecord
  DIRECTIONS = %w[outbound_to_support inbound_from_support system internal_note].freeze
  STATUSES   = %w[queued sent delivered failed read].freeze

  belongs_to :user, optional: true
  belongs_to :support_text_thread

  has_many_attached :images

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :set_defaults, on: :create
  after_commit :broadcast_realtime_updates, on: :create

  validate :body_or_images_present
  validate :image_count_within_limit
  validate :images_content_types
  validate :images_size_limit

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
  scope :visible_to_user, -> { where(visible_to_user: true) }
  scope :internal_only, -> { where(visible_to_user: false) }

  def outbound_to_support?
    direction == "outbound_to_support"
  end

  def inbound_from_support?
    direction == "inbound_from_support"
  end

  def system?
    direction == "system"
  end

  def internal_note?
    direction == "internal_note"
  end

  def failed?
    status == "failed"
  end

  def delivered?
    status == "delivered"
  end

  def read?
    status == "read"
  end

  private

  def broadcast_realtime_updates
    SupportTextRealtimeBroadcaster.new(self).broadcast!
  end

  def set_defaults
    self.status ||= "sent"
    self.intro_message = false if intro_message.nil?
    self.visible_to_user = true if visible_to_user.nil?
    self.metadata ||= {}
  end

  def body_or_images_present
    return if internal_note?
    return if body.present? || images.attached?

    errors.add(:base, "Message must include text or at least one image")
  end

  def image_count_within_limit
    return unless images.attached?
    return unless images.attachments.size > 4

    errors.add(:images, "Maximum 4 images per message")
  end

  def images_content_types
    return unless images.attached?

    allowed = %w[image/jpeg image/png image/webp image/heic image/heif]

    images.each do |image|
      next if image.content_type.in?(allowed)

      errors.add(:images, "Only JPEG, PNG, WEBP, HEIC, and HEIF are allowed")
    end
  end

  def images_size_limit
    return unless images.attached?

    images.each do |image|
      next if image.blob.byte_size <= 8.megabytes

      errors.add(:images, "Each image must be 8MB or smaller")
    end
  end
end