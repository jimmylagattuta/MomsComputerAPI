# app/services/ringcentral/sync_blocked_caller.rb

module Ringcentral
  class SyncBlockedCaller
    def self.call(user, time = Time.current)
      new(user, time).call
    end

    def initialize(user, time)
      @user = user
      @time = time
    end

    def call
      return failure!("missing_user") unless user.present?
      return failure!("missing_phone") if user.phone.blank?

      cycle = user.support_call_cycles.current_for_time(time).order(cycle_start_at: :desc).first

      unless cycle.present?
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] No current cycle; unblocking user_id=#{user.id}"
        )

        return Ringcentral::UnblockPhoneNumber.call(user.phone)
      end

      if cycle.calls_used >= cycle.calls_allowed
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] Blocking over-limit user_id=#{user.id} " \
          "phone=#{user.phone} calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed}"
        )

        Ringcentral::BlockPhoneNumber.call(user.phone)
      else
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] Unblocking under-limit user_id=#{user.id} " \
          "phone=#{user.phone} calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed}"
        )

        Ringcentral::UnblockPhoneNumber.call(user.phone)
      end
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Sync Blocked Caller] FAILED user_id=#{user&.id} " \
        "#{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        user_id: user&.id,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :user, :time

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Sync Blocked Caller] Cannot sync user_id=#{user&.id} reason=#{reason}"
      )

      {
        success: false,
        user_id: user&.id,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end