# app/services/support_text_policy.rb
class SupportTextPolicy
  HOURLY_MESSAGE_LIMIT  = 40
  DAILY_MESSAGE_LIMIT   = 150
  MONTHLY_MESSAGE_LIMIT = 600
  DAILY_IMAGE_LIMIT     = 20

  Result = Struct.new(:allowed, :reason, keyword_init: true)

  def self.check!(user:, image_count:)
    new(user: user, image_count: image_count).check!
  end

  def initialize(user:, image_count:)
    @user = user
    @image_count = image_count.to_i
  end

  def check!
    return Result.new(allowed: false, reason: "Texting is temporarily cooling down. Please try again shortly.") if cooldown_active?
    return Result.new(allowed: false, reason: "Too many messages this hour. Please slow down a bit.") if hourly_limit_hit?
    return Result.new(allowed: false, reason: "Too many messages today. Please try again tomorrow.") if daily_limit_hit?
    return Result.new(allowed: false, reason: "Monthly message allowance has been exceeded.") if monthly_limit_hit?
    return Result.new(allowed: false, reason: "Too many images today. Please try again tomorrow.") if daily_image_limit_hit?

    Result.new(allowed: true, reason: nil)
  end

  private

  attr_reader :user, :image_count

  def current_thread
    @current_thread ||= user.support_text_threads.active.order(created_at: :desc).first
  end

  def cooldown_active?
    current_thread&.cooldown_active?
  end

  def outbound_scope
    SupportTextMessage.where(user: user, direction: "outbound_to_support")
  end

  def hourly_limit_hit?
    outbound_scope.where("support_text_messages.created_at >= ?", 1.hour.ago).count >= HOURLY_MESSAGE_LIMIT
  end

  def daily_limit_hit?
    outbound_scope.where("support_text_messages.created_at >= ?", 24.hours.ago).count >= DAILY_MESSAGE_LIMIT
  end

  def monthly_limit_hit?
    outbound_scope.where("support_text_messages.created_at >= ?", 30.days.ago).count >= MONTHLY_MESSAGE_LIMIT
  end

  def daily_image_limit_hit?
    used_today =
      outbound_scope
        .where("support_text_messages.created_at >= ?", 24.hours.ago)
        .joins("LEFT JOIN active_storage_attachments asa ON asa.record_type = 'SupportTextMessage' AND asa.record_id = support_text_messages.id")
        .count

    (used_today + image_count) > DAILY_IMAGE_LIMIT
  end
end