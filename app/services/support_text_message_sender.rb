# app/services/support_text_message_sender.rb
class SupportTextMessageSender
  def self.call(thread:, body:, image_signed_ids:)
    new(thread: thread, body: body, image_signed_ids: image_signed_ids).call
  end

  def initialize(thread:, body:, image_signed_ids:)
    @thread = thread
    @user = thread.user
    @body = body.to_s.strip
    @image_signed_ids = Array(image_signed_ids).compact
  end

  def call
    policy = SupportTextPolicy.check!(user: @user, image_count: @image_signed_ids.length)
    raise StandardError, policy.reason unless policy.allowed

    message = @thread.support_text_messages.new(
      user: @user,
      direction: "outbound_to_support",
      status: "sent",
      body: @body.presence,
      sent_at: Time.current,
      visible_to_user: true
    )

    attach_signed_images!(message, @image_signed_ids)

    unless message.valid?
      Rails.logger.error("SupportTextMessageSender validation failed: #{message.errors.full_messages.join(', ')}")
      raise StandardError, message.errors.full_messages.to_sentence
    end

    # Save the message
    message.save!

    # Force reload on the same connection to ensure visibility
    message.reload

    # Optional: clear connection-level query cache (helps in some pooled setups)
    if ActiveRecord::Base.connection.respond_to?(:clear_query_cache)
      ActiveRecord::Base.connection.clear_query_cache
    end

    # Bump thread timestamps and reload thread object
    @thread.touch(:updated_at, :last_message_at)
    @thread.reload

    # Update cycle counters if applicable
    if @thread.support_text_cycle.present?
      @thread.support_text_cycle.increment!(:messages_used)
      @thread.support_text_cycle.increment!(:images_used, message.images.count) if @thread.support_text_cycle.respond_to?(:images_used)
    end

    # Final thread status update
    @thread.update!(
      status: "waiting_on_support",
      last_message_at: Time.current,
      last_user_message_at: Time.current,
      support_unread: true,
      user_unread: false
    )

    # Optional last-resort delay — uncomment only if problem persists
    # sleep(0.05) if Rails.env.production? || Rails.env.staging?

    Rails.logger.info("SupportTextMessageSender created message ##{message.id} visible_to_user=#{message.visible_to_user} for thread ##{@thread.id}")

    message
  end

  private

  def attach_signed_images!(message, signed_ids)
    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      message.images.attach(blob)
    end
  end
end