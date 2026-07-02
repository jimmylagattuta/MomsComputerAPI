module SupportCalls
  class FinalizeExpiredAnsweredCalls
    def self.call
      new.call
    end

    def call
      finalized = []
      skipped = []
      failed = []

      sessions.find_each do |session|
        begin
          result = SupportCalls::FinalizeAnsweredCallJob.perform_now(session.id)

          if result
            finalized << session.id
          else
            skipped << session.id
          end
        rescue StandardError => e
          failed << {
            session_id: session.id,
            error_class: e.class.name,
            error_message: e.message
          }

          Rails.logger.error(
            "[SupportCalls::FinalizeExpiredAnsweredCalls] failed " \
            "session_id=#{session.id} #{e.class}: #{e.message}"
          )
          Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
        end
      end

      summary = {
        success: failed.empty?,
        finalized_count: finalized.length,
        skipped_count: skipped.length,
        failed_count: failed.length,
        finalized_session_ids: finalized,
        skipped_session_ids: skipped,
        failed: failed
      }

      Rails.logger.info(
        "[SupportCalls::FinalizeExpiredAnsweredCalls] finished summary=#{summary.inspect}"
      )

      summary
    end

    private

    def sessions
      SupportCallSession
        .where(status: "completed")
        .where(chargeable: false, charged_at: nil)
        .where.not(answered_at: nil)
        .where.not(ended_at: nil)
        .where.not(buffer_expires_at: nil)
        .where("buffer_expires_at <= ?", Time.current)
        .order(buffer_expires_at: :asc)
    end
  end
end
