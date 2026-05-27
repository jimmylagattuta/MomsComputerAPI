module SupportCalls
  class FinalizeAnsweredCallJob < ApplicationJob
    queue_as :default

    def perform(support_call_session_id)
      session = SupportCallSession.find_by(id: support_call_session_id)

      unless session.present?
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] session missing " \
          "session_id=#{support_call_session_id}"
        )

        return false
      end

      session.reload

      unless session.answered?
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] skipped not answered " \
          "session_id=#{session.id}"
        )

        return false
      end

      unless session.ended?
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] skipped not ended " \
          "session_id=#{session.id}"
        )

        return false
      end

      if session.charged?
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] skipped already charged " \
          "session_id=#{session.id}"
        )

        return false
      end

      if session.buffer_expires_at.present? && session.buffer_expires_at > Time.current
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] buffer still active; rescheduling " \
          "session_id=#{session.id} buffer_expires_at=#{session.buffer_expires_at}"
        )

        self.class.set(wait_until: session.buffer_expires_at).perform_later(session.id)

        return false
      end

      if session.newer_answered_reconnect_exists?
        Rails.logger.info(
          "[SupportCalls::FinalizeAnsweredCallJob] skipped superseded by newer answered reconnect " \
          "session_id=#{session.id} user_id=#{session.user_id}"
        )

        return false
      end

      session.mark_chargeable!

      Rails.logger.info(
        "[SupportCalls::FinalizeAnsweredCallJob] charged answered support call " \
        "session_id=#{session.id} user_id=#{session.user_id} " \
        "calls_used=#{session.support_call_cycle.reload.calls_used} " \
        "calls_allowed=#{session.support_call_cycle.calls_allowed}"
      )

      true
    rescue StandardError => e
      Rails.logger.error(
        "[SupportCalls::FinalizeAnsweredCallJob] FAILED " \
        "session_id=#{support_call_session_id} #{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      raise e
    end
  end
end