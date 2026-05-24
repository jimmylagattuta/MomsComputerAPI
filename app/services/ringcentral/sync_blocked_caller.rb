# app/services/ringcentral/sync_blocked_caller.rb

module Ringcentral
  class SyncBlockedCaller
    def self.call(user_arg = nil, time = Time.current, user: nil)
      resolved_user = user_arg || user

      new(resolved_user, time).call
    end

    def initialize(user, time = Time.current)
      @user = user
      @time = time
    end

    def call
      return failure!("missing_user") unless user.present?
      return failure!("missing_phone") if normalized_phone.blank?

      cycle = current_cycle

      unless cycle.present?
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] No current cycle; unblocking user_id=#{user.id} phone=#{normalized_phone}"
        )

        return Ringcentral::UnblockPhoneNumber.call(normalized_phone)
      end

      if active_reconnect_buffer?
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] Active reconnect buffer; keeping user unblocked " \
          "user_id=#{user.id} phone=#{normalized_phone}"
        )

        return Ringcentral::UnblockPhoneNumber.call(normalized_phone)
      end

      if cycle.calls_used >= cycle.calls_allowed
        Rails.logger.info(
          "[RingCentral Sync Blocked Caller] Blocking over-limit user_id=#{user.id} " \
          "phone=#{normalized_phone} calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed}"
        )

        return Ringcentral::BlockPhoneNumber.call(normalized_phone)
      end

      Rails.logger.info(
        "[RingCentral Sync Blocked Caller] Unblocking under-limit user_id=#{user.id} " \
        "phone=#{normalized_phone} calls_used=#{cycle.calls_used} calls_allowed=#{cycle.calls_allowed}"
      )

      Ringcentral::UnblockPhoneNumber.call(normalized_phone)
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Sync Blocked Caller] FAILED user_id=#{user&.id} " \
        "#{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        user_id: user&.id,
        phone: normalized_phone,
        error_class: e.class.name,
        error_message: e.message
      }
    end

    private

    attr_reader :user, :time

    def current_cycle
      user.support_call_cycles
        .current_for_time(time)
        .order(cycle_start_at: :desc)
        .first
    end

    def active_reconnect_buffer?
      user.support_call_sessions
        .where("buffer_expires_at > ?", time)
        .exists?
    end

    def normalized_phone
      @normalized_phone ||= user&.phone.to_s.strip.presence
    end

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Sync Blocked Caller] Cannot sync user_id=#{user&.id} reason=#{reason}"
      )

      {
        success: false,
        user_id: user&.id,
        phone: normalized_phone,
        error_class: "ValidationError",
        error_message: reason
      }
    end
  end
end