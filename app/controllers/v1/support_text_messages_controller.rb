# app/controllers/v1/support_text_messages_controller.rb
class V1::SupportTextMessagesController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!

  def index
    thread = current_user.support_text_threads.find(params[:thread_id] || current_thread_id_param)

    messages = thread.support_text_messages
                    .where(visible_to_user: [true, nil])
                    .chronological
                    .includes(images_attachments: :blob)

    render json: {
      messages: messages.map { |message| serialize_message(message) }
    }, status: :ok
  end

  def create
    thread = current_user.support_text_threads.find(params[:thread_id] || current_thread_id_param)

    cleaned_body = params[:body].to_s.strip

    uploaded_images = params[:images]
    uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
    uploaded_images = uploaded_images.compact

    cleaned_image_signed_ids = Array(params[:image_signed_ids]).map(&:presence).compact

    # 🔍 LOGGING (BEFORE VALIDATION)
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

    sleep 0.2

    render json: { message: serialize_message(message) }, status: :created
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