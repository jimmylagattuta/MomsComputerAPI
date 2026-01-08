# app/controllers/v1/attachments_controller.rb
module V1
  class AttachmentsController < ApplicationController
    include JwtAuth

    # POST /v1/messages/:id/attachments
    # Expects multipart form-data: file, attachment_type (optional)
    def create
      message = Message.joins(:conversation).where(conversations: { user_id: current_user.id }).find(params[:id])

      uploaded = params.require(:file)
      attachment_type = params[:attachment_type].presence || "screenshot"

      attachment = message.attachments.create!(
        attachment_type: attachment_type,
        filename: uploaded.original_filename,
        content_type: uploaded.content_type,
        byte_size: uploaded.size
      )

      attachment.file.attach(uploaded)

      render json: {
        attachment_id: attachment.id,
        message_id: message.id,
        attachment_type: attachment.attachment_type,
        filename: attachment.filename,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size
      }, status: :created
    end
  end
end