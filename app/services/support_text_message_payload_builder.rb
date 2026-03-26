class SupportTextMessagePayloadBuilder
  include Rails.application.routes.url_helpers

  def initialize(message)
    @message = message
  end

  def as_json
    {
      id: @message.id,
      direction: @message.direction,
      status: @message.status,
      body: @message.body,
      created_at: @message.created_at,
      intro_message: @message.intro_message,
      author_agent_name: @message.author_agent_name,
      visible_to_user: @message.visible_to_user,
      images: images_payload
    }
  rescue StandardError => e
    Rails.logger.error("[PayloadBuilder] Failed for message #{@message&.id}: #{e.message}")
    {}
  end

  private

  def images_payload
    return [] unless @message.respond_to?(:images_attachments)

    @message.images_attachments.includes(:blob).map do |attachment|
      build_attachment_payload(attachment)
    end.compact
  end

  def build_attachment_payload(attachment)
    {
      id: attachment.id,
      url: rails_blob_url(attachment, host: default_host),
      filename: attachment.filename.to_s,
      content_type: attachment.blob.content_type,
      byte_size: attachment.blob.byte_size
    }
  rescue StandardError => e
    Rails.logger.error("[PayloadBuilder] Attachment failed id=#{attachment&.id}: #{e.message}")
    nil
  end

  def default_host
    Rails.application.routes.default_url_options[:host] ||
      ENV["APP_BASE_URL"] ||
      "http://localhost:3000"
  end
end