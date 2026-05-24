# app/services/ringcentral/sync_all_blocked_callers.rb

module Ringcentral
  class SyncAllBlockedCallers
    def self.call(time = Time.current)
      new(time).call
    end

    def self.call_monthly_if_first_day(time = Time.current)
      unless time.day == 1
        Rails.logger.info(
          "[RingCentral Sync All Blocked Callers] Monthly sync skipped. " \
          "Today is not the first day of the month. time=#{time} day=#{time.day}"
        )

        return {
          success: true,
          skipped: true,
          reason: "not_first_day_of_month",
          time: time
        }
      end

      Rails.logger.info(
        "[RingCentral Sync All Blocked Callers] Monthly sync running because today is the first day of the month. time=#{time}"
      )

      call(time)
    end

    def initialize(time)
      @time = time
      @results = []
    end

    def call
      Rails.logger.info(
        "[RingCentral Sync All Blocked Callers] Starting time=#{time}"
      )

      users.find_each do |user|
        sync_user(user)
      end

      summary = build_summary

      Rails.logger.info(
        "[RingCentral Sync All Blocked Callers] Finished summary=#{summary.inspect}"
      )

      {
        success: true,
        skipped: false,
        time: time,
        summary: summary,
        results: results
      }
    rescue StandardError => e
      Rails.logger.error(
        "[RingCentral Sync All Blocked Callers] FAILED #{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      {
        success: false,
        skipped: false,
        time: time,
        error_class: e.class.name,
        error_message: e.message,
        summary: build_summary,
        results: results
      }
    end

    private

    attr_reader :time, :results

    def users
      User.where.not(phone: [nil, ""])
    end

    def sync_user(user)
      cycle = user.current_support_call_cycle(time)
      result = Ringcentral::SyncBlockedCaller.call(user, time)

      row = {
        user_id: user.id,
        email: user.email,
        phone: user.phone,
        cycle_id: cycle.id,
        calls_allowed: cycle.calls_allowed,
        calls_used: cycle.calls_used,
        calls_remaining: cycle.calls_remaining,
        ringcentral_success: result[:success],
        ringcentral_result: result
      }

      results << row

      Rails.logger.info(
        "[RingCentral Sync All Blocked Callers] Synced user_id=#{user.id} " \
        "phone=#{user.phone} calls_used=#{cycle.calls_used} " \
        "calls_allowed=#{cycle.calls_allowed} calls_remaining=#{cycle.calls_remaining} " \
        "ringcentral_success=#{result[:success]}"
      )

      row
    rescue StandardError => e
      row = {
        user_id: user&.id,
        email: user&.email,
        phone: user&.phone,
        ringcentral_success: false,
        error_class: e.class.name,
        error_message: e.message
      }

      results << row

      Rails.logger.error(
        "[RingCentral Sync All Blocked Callers] User sync failed " \
        "user_id=#{user&.id} #{e.class}: #{e.message}"
      )
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      row
    end

    def build_summary
      {
        total: results.length,
        succeeded: results.count { |row| row[:ringcentral_success] == true },
        failed: results.count { |row| row[:ringcentral_success] == false },
        blocked_or_kept_blocked: results.count do |row|
          row.dig(:ringcentral_result, :phone).present? &&
            row[:calls_allowed].present? &&
            row[:calls_used].present? &&
            row[:calls_used] >= row[:calls_allowed]
        end,
        unblocked_or_kept_unblocked: results.count do |row|
          row[:calls_allowed].present? &&
            row[:calls_used].present? &&
            row[:calls_used] < row[:calls_allowed]
        end
      }
    end
  end
end