# app/controllers/v1/support/text_messages_controller.rb
class V1::Support::TextMessagesController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!
  before_action :require_admin!

  def index
    thread = SupportTextThread.find(params[:text_thread_id])

    messages = thread.support_text_messages
                     .chronological
                     .includes(images_attachments: :blob)

    render json: {
      messages: messages.map { |message| serialize_message(message) }
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Support thread not found." }, status: :not_found
  rescue => e
    Rails.logger.error("V1::Support::TextMessagesController#index failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

    render json: { error: "Unable to load messages." }, status: :unprocessable_entity
  end

  def create
    thread = SupportTextThread.find(params[:text_thread_id])

    cleaned_body = params[:body].to_s.strip

    uploaded_images = params[:images]
    uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
    uploaded_images = uploaded_images.compact

    cleaned_image_signed_ids = Array(params[:image_signed_ids]).map(&:presence).compact

    admin_display_name =
      [current_user.first_name, current_user.last_name]
        .map(&:presence)
        .compact
        .join(" ")
        .presence || current_user.email

    Rails.logger.info("======== SUPPORT TEXT ADMIN CREATE ========")
    Rails.logger.info("RAW PARAMS: #{params.to_unsafe_h.except(:images).inspect}")
    Rails.logger.info("THREAD ID: #{thread.id}")
    Rails.logger.info("ADMIN USER ID: #{current_user.id}")
    Rails.logger.info("ADMIN USER NAME: #{admin_display_name}")
    Rails.logger.info("BODY: #{cleaned_body.inspect}")
    Rails.logger.info("SIGNED IDS COUNT: #{cleaned_image_signed_ids.length}")
    Rails.logger.info("UPLOADED IMAGES COUNT: #{uploaded_images.length}")
    Rails.logger.info("UPLOADED IMAGES CLASS: #{uploaded_images.map(&:class).inspect}")
    Rails.logger.info("===========================================")

    if cleaned_body.blank? && cleaned_image_signed_ids.blank? && uploaded_images.blank?
      return render json: { error: "Message content is required." }, status: :unprocessable_entity
    end

    message = thread.support_text_messages.new(
      user: thread.user,
      direction: "inbound_from_support",
      status: "sent",
      body: cleaned_body.presence,
      sent_at: Time.current,
      visible_to_user: true,
      author_agent_id: current_user.id,
      author_agent_name: admin_display_name
    )

    Rails.logger.info("Admin support message: saving without validation before attaching images")
    message.save!(validate: false)

    attach_signed_images!(message, cleaned_image_signed_ids) if cleaned_image_signed_ids.present?
    attach_uploaded_images!(message, uploaded_images) if uploaded_images.present?

    message.reload

    Rails.logger.info(
      "Admin support message: post-attach message ##{message.id} " \
      "body_present=#{message.body.present?} image_count=#{message.images.count}"
    )

    verify_uploaded_blobs!(message)

    unless message.valid?
      errors = message.errors.full_messages.to_sentence
      Rails.logger.error("Admin support message validation failed after attach: #{errors}")
      cleanup_failed_message!(message)
      raise ActiveRecord::RecordInvalid.new(message)
    end

    message.save!(validate: false)

    if ActiveRecord::Base.connection.respond_to?(:clear_query_cache)
      ActiveRecord::Base.connection.clear_query_cache
    end

    now = message.created_at || Time.current

    SupportTextThread.transaction do
      thread.reload

      thread.update!(
        status: "waiting_on_user",
        last_message_at: now,
        last_support_message_at: now,
        user_unread: true,
        support_unread: false,
        assigned_agent_id: thread.assigned_agent_id || current_user.id,
        assigned_agent_name: thread.assigned_agent_name.presence || admin_display_name,
        started_at: thread.started_at || now
      )
    end

    SupportTextNotificationService.notify_new_message!(message)

    render json: {
      ok: true,
      message: serialize_message(message),
      thread: serialize_thread_summary(thread.reload)
    }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Support thread not found." }, status: :not_found
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: { error: "One or more images were invalid or expired." }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("V1::Support::TextMessagesController#create validation failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

    render json: {
      error: e.record&.errors&.full_messages&.to_sentence.presence || "Unable to send message."
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotSaved => e
    Rails.logger.error("V1::Support::TextMessagesController#create save failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

    render json: { error: "Unable to send message." }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("V1::Support::TextMessagesController#create failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

    cleanup_failed_message!(message) if defined?(message) && message.present? && message.persisted?

    render json: { error: e.message.presence || "Unable to send message." }, status: :unprocessable_entity
  end

  private

  def require_admin!
    return if current_user&.role == "admin"

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def attach_signed_images!(message, signed_ids)
    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      Rails.logger.info(
        "Attaching signed blob ##{blob.id} key=#{blob.key} to admin message ##{message.id}"
      )
      message.images.attach(blob)
    end
  end

  def attach_uploaded_images!(message, files)
    files.each do |file|
      Rails.logger.info(
        "Attaching uploaded image to admin message ##{message.id} " \
        "filename=#{file.original_filename} " \
        "content_type=#{file.content_type} " \
        "tempfile_path=#{file.tempfile.path}"
      )

      message.images.attach(file)

      latest_blob = message.images.blobs.last
      if latest_blob.present?
        Rails.logger.info(
          "Admin support message attached blob ##{latest_blob.id} " \
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
        "Admin support message blob check " \
        "id=#{blob.id} key=#{blob.key} exists=#{exists}"
      )

      missing_blob_ids << blob.id unless exists
    end

    return if missing_blob_ids.empty?

    Rails.logger.error(
      "Admin support message missing uploaded blobs for message ##{message.id}: #{missing_blob_ids.join(', ')}"
    )

    cleanup_failed_message!(message)
    raise StandardError, "One or more uploaded images failed to persist to storage."
  end

  def cleanup_failed_message!(message)
    begin
      message.images.purge
    rescue => purge_error
      Rails.logger.error(
        "Admin support message purge failed for message ##{message.id}: #{purge_error.class} - #{purge_error.message}"
      )
    end

    begin
      message.destroy!
    rescue => destroy_error
      Rails.logger.error(
        "Admin support message destroy failed for message ##{message.id}: #{destroy_error.class} - #{destroy_error.message}"
      )
    end
  end

  def serialize_message(message)
    {
      id: message.id,
      direction: message.direction,
      status: message.status,
      body: message.body,
      sent_at: message.sent_at,
      delivered_at: message.delivered_at,
      read_at: message.read_at,
      failed_at: message.failed_at,
      failure_reason: message.failure_reason,
      intro_message: message.intro_message,
      author_agent_name: message.author_agent_name,
      images: message.images.map do |image|
        {
          id: image.id,
          filename: image.filename.to_s,
          content_type: image.content_type,
          byte_size: image.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_url(image, host: request.base_url)
        }
      end,
      created_at: message.created_at
    }
  end

  def serialize_thread_summary(thread)
    {
      id: thread.id,
      status: thread.status,
      priority: thread.priority,
      support_unread: thread.support_unread,
      user_unread: thread.user_unread,
      assigned_agent_id: thread.assigned_agent_id,
      assigned_agent_name: thread.assigned_agent_name,
      started_at: thread.started_at,
      last_message_at: thread.last_message_at,
      last_user_message_at: thread.last_user_message_at,
      last_support_message_at: thread.last_support_message_at,
      support_identity_snapshot: thread.support_identity_snapshot
    }
  end
end