# app/services/support_text_message_sender.rb
class SupportTextMessageSender
  def self.call(thread:, body:, image_signed_ids: [], uploaded_images: [])
    new(
      thread: thread,
      body: body,
      image_signed_ids: image_signed_ids,
      uploaded_images: uploaded_images
    ).call
  end

  def initialize(thread:, body:, image_signed_ids: [], uploaded_images: [])
    @thread = thread
    @user = thread.user
    @body = body.to_s.strip
    @image_signed_ids = Array(image_signed_ids).map(&:presence).compact
    @uploaded_images = Array(uploaded_images).compact
  end

  def call
    total_image_count = @image_signed_ids.length + @uploaded_images.length

    policy = SupportTextPolicy.check!(user: @user, image_count: total_image_count)
    raise StandardError, policy.reason unless policy.allowed

    if @body.blank? && @image_signed_ids.blank? && @uploaded_images.blank?
      raise StandardError, "Message content is required."
    end

    message = @thread.support_text_messages.new(
      user: @user,
      direction: "outbound_to_support",
      status: "sent",
      body: @body.presence,
      sent_at: Time.current,
      visible_to_user: true
    )

    Rails.logger.info("SupportTextMessageSender: saving message without validation before attaching images")
    message.save!(validate: false)

    attach_signed_images!(message, @image_signed_ids) if @image_signed_ids.present?
    attach_uploaded_images!(message, @uploaded_images) if @uploaded_images.present?

    message.reload

    Rails.logger.info(
      "SupportTextMessageSender: post-attach message ##{message.id} " \
      "body_present=#{message.body.present?} image_count=#{message.images.count}"
    )

    verify_uploaded_blobs!(message)

    unless message.valid?
      errors = message.errors.full_messages.to_sentence
      Rails.logger.error("SupportTextMessageSender validation failed after attach: #{errors}")
      cleanup_failed_message!(message)
      raise ActiveRecord::RecordInvalid.new(message)
    end

    message.save!(validate: false)

    if ActiveRecord::Base.connection.respond_to?(:clear_query_cache)
      ActiveRecord::Base.connection.clear_query_cache
    end

    ActiveRecord::Base.transaction do
      @thread.touch(:updated_at, :last_message_at)
      @thread.reload

      if @thread.support_text_cycle.present?
        @thread.support_text_cycle.increment!(:messages_used)
        if @thread.support_text_cycle.respond_to?(:images_used)
          @thread.support_text_cycle.increment!(:images_used, message.images.count)
        end
      end

      @thread.update!(
        status: "waiting_on_support",
        last_message_at: Time.current,
        last_user_message_at: Time.current,
        support_unread: true,
        user_unread: false
      )
    end

    Rails.logger.info(
      "SupportTextMessageSender created message ##{message.id} " \
      "visible_to_user=#{message.visible_to_user} for thread ##{@thread.id}"
    )

    message
  rescue => e
    Rails.logger.error(
      "SupportTextMessageSender failed for thread ##{@thread&.id}: #{e.class} - #{e.message}"
    )
    raise
  end

  private

  def attach_signed_images!(message, signed_ids)
    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      Rails.logger.info(
        "Attaching signed blob ##{blob.id} key=#{blob.key} to message ##{message.id}"
      )
      message.images.attach(blob)
    end
  end

  def attach_uploaded_images!(message, files)
    files.each do |file|
      Rails.logger.info(
        "Attaching uploaded image to message ##{message.id} " \
        "filename=#{file.original_filename} " \
        "content_type=#{file.content_type} " \
        "tempfile_path=#{file.tempfile.path}"
      )

      message.images.attach(file)

      latest_blob = message.images.blobs.last
      if latest_blob.present?
        Rails.logger.info(
          "SupportTextMessageSender attached blob ##{latest_blob.id} " \
          "key=#{latest_blob.key} filename=#{latest_blob.filename}"
        )
      end
    end
  end

  def verify_uploaded_blobs!(message)
    missing_blob_ids = []

    message.images.blobs.each do |blob|
      exists = blob.service.exist?(blob.key)

      Rails.logger.info(
        "SupportTextMessageSender blob check " \
        "id=#{blob.id} key=#{blob.key} exists=#{exists}"
      )

      missing_blob_ids << blob.id unless exists
    end

    return if missing_blob_ids.empty?

    Rails.logger.error(
      "SupportTextMessageSender missing uploaded blobs for message ##{message.id}: #{missing_blob_ids.join(', ')}"
    )

    cleanup_failed_message!(message)
    raise StandardError, "One or more uploaded images failed to persist to storage."
  end

  def cleanup_failed_message!(message)
    begin
      message.images.purge
    rescue => purge_error
      Rails.logger.error(
        "SupportTextMessageSender purge failed for message ##{message.id}: #{purge_error.class} - #{purge_error.message}"
      )
    end

    begin
      message.destroy!
    rescue => destroy_error
      Rails.logger.error(
        "SupportTextMessageSender destroy failed for message ##{message.id}: #{destroy_error.class} - #{destroy_error.message}"
      )
    end
  end
end