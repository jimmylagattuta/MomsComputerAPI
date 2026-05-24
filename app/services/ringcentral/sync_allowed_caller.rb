# app/services/ringcentral/sync_allowed_caller.rb

module Ringcentral
  class SyncAllowedCaller
    def self.call(user_arg = nil, user: nil)
      resolved_user = user_arg || user

      new(resolved_user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      return failure!("missing_user") unless user.present?
      return failure!("missing_phone") if normalized_phone.blank?

      Rails.logger.info(
        "[RingCentral Sync Allowed Caller] Allowing user_id=#{user.id} phone=#{normalized_phone}"
      )

      result = Ringcentral::UnblockPhoneNumber.call(normalized_phone)

      Rails.logger.info(
        "[RingCentral Sync Allowed Caller] Complete user_id=#{user.id} " \
        "phone=#{normalized_phone} result=#{result.inspect}"
      )

      result
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Sync Allowed Caller] FAILED user_id=#{user&.id} " \
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

    attr_reader :user

    def normalized_phone
      @normalized_phone ||= user&.phone.to_s.strip.presence
    end

    def failure!(reason)
      Rails.logger.error(
        "[RingCentral Sync Allowed Caller] Cannot sync user_id=#{user&.id} reason=#{reason}"
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