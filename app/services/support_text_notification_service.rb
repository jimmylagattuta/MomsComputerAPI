# app/services/support_text_notification_service.rb
class SupportTextNotificationService
  PREVIEW_LENGTH = 120

  class << self
    def notify_new_message!(message)
      return false if message.blank?

      thread = message.support_text_thread
      return false if thread.blank?

      if message.inbound_from_support?
        notify_user_about_admin_reply(thread, message)
      elsif message.outbound_to_support?
        notify_admins_about_user_message(thread, message)
      else
        Rails.logger.info(
          "[SupportTextNotificationService] Skipping push for message ##{message.id} direction=#{message.direction}"
        )
        false
      end
    rescue => e
      Rails.logger.error(
        "[SupportTextNotificationService] notify_new_message! failed: #{e.class} - #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
      false
    end

    private

    def notify_user_about_admin_reply(thread, message)
      user = thread.user
      return false unless user.present?

      tokens = user.active_devices.pluck(:push_token)

      result = ExpoPushService.send_to_tokens!(
        tokens: tokens,
        title: "Mom replied 💬",
        body: message_preview(message),
        data: {
          type: "support_text",
          thread_id: thread.id,
          message_id: message.id
        }
      )

      Rails.logger.info(
        "[SupportTextNotificationService] Admin -> User push result for message ##{message.id}: #{result.inspect}"
      )

      result
    end

    def notify_admins_about_user_message(thread, message)
      tokens = User.where(role: "admin")
                   .joins(:devices)
                   .merge(Device.active)
                   .pluck("devices.push_token")

      result = ExpoPushService.send_to_tokens!(
        tokens: tokens,
        title: "New support message",
        body: message_preview(message),
        data: {
          type: "support_text",
          thread_id: thread.id,
          message_id: message.id
        }
      )

      Rails.logger.info(
        "[SupportTextNotificationService] User -> Admin push result for message ##{message.id}: #{result.inspect}"
      )

      result
    end

    def message_preview(message)
      text = message.body.to_s.strip

      if text.present?
        text.length > PREVIEW_LENGTH ? "#{text.first(PREVIEW_LENGTH)}..." : text
      elsif message.images.attached?
        "Sent an image"
      else
        "New message"
      end
    end
  end
end