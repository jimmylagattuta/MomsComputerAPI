# app/controllers/v1/support/text_messages_controller.rb
class V1::Support::TextMessagesController < ApplicationController
  include JwtAuth
  
  before_action :authenticate_user!
  before_action :require_support_agent!

  def index
    thread = SupportTextThread.find(params[:text_thread_id])

    messages = thread.support_text_messages
                     .chronological
                     .includes(images_attachments: :blob)

    thread.update!(support_unread: false)

    render json: {
      messages: messages.map { |message| serialize_message(message) }
    }, status: :ok
  end

  def create
    thread = SupportTextThread.find(params[:text_thread_id])

    message = SupportTextReplySender.call(
      thread: thread,
      body: params[:body],
      image_signed_ids: params[:image_signed_ids],
      agent: current_user
    )

    render json: { message: serialize_message(message) }, status: :created
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: { error: "One or more images were invalid or expired." }, status: :unprocessable_entity
  rescue => e
    render json: { error: e.message.presence || "Unable to send message." }, status: :unprocessable_entity
  end

  private

  def require_support_agent!
    head :forbidden unless current_user&.admin?
  end

  def serialize_message(message)
    {
      id: message.id,
      direction: message.direction,
      status: message.status,
      body: message.body,
      sent_at: message.sent_at,
      intro_message: message.intro_message,
      visible_to_user: message.visible_to_user,
      author_agent_id: message.author_agent_id,
      author_agent_name: message.author_agent_name,
      images: message.images.map do |image|
        {
          id: image.id,
          filename: image.filename.to_s,
          content_type: image.content_type,
          byte_size: image.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_url(image, only_path: false)
        }
      end,
      created_at: message.created_at
    }
  end
end