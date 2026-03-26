class SupportTextThreadSummaryPayloadBuilder
  def initialize(thread)
    @thread = thread
  end

  def as_json
    {
      id: @thread.id,
      status: @thread.status,
      priority: @thread.priority,
      assigned_agent_id: @thread.assigned_agent_id,
      assigned_agent_name: @thread.assigned_agent_name,
      started_at: @thread.started_at,
      last_message_at: @thread.last_message_at,
      last_user_message_at: @thread.last_user_message_at,
      last_support_message_at: @thread.last_support_message_at,
      cooldown_until: @thread.cooldown_until,
      blocked: @thread.blocked,
      support_unread: @thread.support_unread,
      user_unread: @thread.user_unread,
      support_identity_snapshot: @thread.support_identity_snapshot
    }
  rescue StandardError => e
    Rails.logger.error("[ThreadSummaryPayload] Failed for thread #{@thread&.id}: #{e.message}")
    {}
  end
end