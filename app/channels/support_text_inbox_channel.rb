class SupportTextInboxChannel < ApplicationCable::Channel
  def subscribed
    unless current_user&.role == "admin"
      Rails.logger.warn("[Cable] Inbox access denied for user #{current_user&.id}")
      reject
      return
    end

    stream_for "support_admin_inbox"
  end
end