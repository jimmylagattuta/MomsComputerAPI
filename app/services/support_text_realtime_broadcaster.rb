class SupportTextRealtimeBroadcaster
  def initialize(message)
    @message = message
    @thread = message.support_text_thread
  end

  def broadcast!
    broadcast_thread_message
    broadcast_admin_inbox_update
  rescue StandardError => e
    Rails.logger.error("[RealtimeBroadcaster] Failed for message #{message&.id}: #{e.message}")
  end

  private

  attr_reader :message, :thread

  def broadcast_thread_message
    SupportTextThreadChannel.broadcast_to(
      thread,
      {
        type: "support_text.message_created",
        thread_id: thread.id,
        message: message_payload,
        thread: thread_summary
      }
    )
  end

  def broadcast_admin_inbox_update
    SupportTextInboxChannel.broadcast_to(
      "support_admin_inbox",
      {
        type: "support_text.thread_updated",
        thread: thread_summary
      }
    )
  end

  def message_payload
    @message_payload ||= SupportTextMessagePayloadBuilder.new(message).as_json
  end

  def thread_summary
    @thread_summary ||= SupportTextThreadSummaryPayloadBuilder.new(thread.reload).as_json
  end
end