# app/services/support_text_reply_sender.rb
class SupportTextReplySender
  def self.call(thread:, body:, image_signed_ids:, agent:)
    new(thread: thread, body: body, image_signed_ids: image_signed_ids, agent: agent).call
  end

  def initialize(thread:, body:, image_signed_ids:, agent:)
    @thread = thread
    @body = body.to_s.strip
    @image_signed_ids = Array(image_signed_ids).compact
    @agent = agent
  end

  def call
    message = @thread.support_text_messages.new(
      user: @thread.user,
      direction: "inbound_from_support",
      status: "sent",
      body: @body.presence,
      sent_at: Time.current,
      visible_to_user: true,
      author_agent_id: @agent.id,
      author_agent_name: agent_name
    )

    attach_signed_images!(message, @image_signed_ids)
    message.save!

    @thread.update!(
      status: "waiting_on_user",
      last_message_at: Time.current,
      last_support_message_at: Time.current,
      user_unread: true,
      support_unread: false,
      assigned_agent_id: @agent.id,
      assigned_agent_name: agent_name
    )

    # TODO:
    # - push notification to user
    # - websocket / actioncable broadcast to user app

    message
  end

  private

  def agent_name
    @agent.try(:name).presence || @agent.try(:email).presence || "Support"
  end

  def attach_signed_images!(message, signed_ids)
    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      message.images.attach(blob)
    end
  end
end