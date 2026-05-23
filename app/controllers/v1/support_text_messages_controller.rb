# app/controllers/v1/support_text_messages_controller.rb
class V1::SupportTextMessagesController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!

  def index
    thread = current_user.support_text_threads.find(params[:thread_id] || current_thread_id_param)

    Rails.logger.info(
      "[TextMomUserBadge] messages#index before read " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect}"
    )

    mark_thread_read_for_user!(thread)

    thread.reload

    Rails.logger.info(
      "[TextMomUserBadge] messages#index after read " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect}"
    )

    messages = thread.support_text_messages
                    .where(visible_to_user: [true, nil])
                    .chronological
                    .includes(images_attachments: :blob)

    render json: {
      messages: messages.map { |message| serialize_message(message) },
      thread: serialize_thread_summary(thread)
    }, status: :ok
  end

  def create
    thread = current_user.support_text_threads.find(params[:thread_id] || current_thread_id_param)

    cleaned_body = params[:body].to_s.strip

    uploaded_images = params[:images]
    uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
    uploaded_images = uploaded_images.compact

    cleaned_image_signed_ids = Array(params[:image_signed_ids]).map(&:presence).compact

    Rails.logger.info("======== SUPPORT TEXT USER CREATE ========")
    Rails.logger.info("RAW PARAMS: #{params.to_unsafe_h.except(:images).inspect}")
    Rails.logger.info("BODY: #{cleaned_body.inspect}")
    Rails.logger.info("SIGNED IDS COUNT: #{cleaned_image_signed_ids.length}")
    Rails.logger.info("UPLOADED IMAGES COUNT: #{uploaded_images.length}")
    Rails.logger.info("UPLOADED IMAGES CLASS: #{uploaded_images.map(&:class).inspect}")
    Rails.logger.info("==========================================")

    if cleaned_body.blank? && cleaned_image_signed_ids.blank? && uploaded_images.blank?
      return render json: { error: "Message content is required." }, status: :unprocessable_entity
    end

    message = SupportTextMessageSender.call(
      thread: thread,
      body: cleaned_body,
      image_signed_ids: cleaned_image_signed_ids,
      uploaded_images: uploaded_images
    )

    now = message.created_at || Time.current

    SupportTextThread.transaction do
      thread.reload

      thread.update!(
        status: "waiting_on_support",
        last_message_at: now,
        last_user_message_at: now,
        support_unread: true,
        user_unread: false,
        started_at: thread.started_at || now
      )
    end

    Rails.logger.info(
      "[TextMomUserBadge] messages#create user sent " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "user_unread=#{thread.reload.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect}"
    )

    SupportTextNotificationService.notify_new_message!(message)

    sleep 0.2

    render json: {
      message: serialize_message(message),
      thread: serialize_thread_summary(thread.reload)
    }, status: :created
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: { error: "One or more images were invalid or expired." }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("SupportTextMessagesController#create failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?

    render json: { error: e.message.presence || "Unable to send message." }, status: :unprocessable_entity
  end

  private

  def current_thread_id_param
    params[:support_text_thread_id]
  end

  def mark_thread_read_for_user!(thread)
    return unless thread.user_unread == true

    thread.update!(user_unread: false)
  end

  def serialize_thread_summary(thread)
    {
      id: thread.id,
      status: thread.status,
      priority: thread.priority,
      support_unread: thread.support_unread == true,
      user_unread: thread.user_unread == true,
      text_mom_unread_count: thread.user_unread == true ? 1 : 0,
      assigned_agent_id: thread.assigned_agent_id,
      assigned_agent_name: thread.assigned_agent_name,
      started_at: thread.started_at,
      last_message_at: thread.last_message_at,
      last_user_message_at: thread.last_user_message_at,
      last_support_message_at: thread.last_support_message_at,
      support_identity_snapshot: thread.support_identity_snapshot
    }
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
end