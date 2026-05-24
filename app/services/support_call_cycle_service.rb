class SupportCallCycleService
  DEFAULT_CALLS_ALLOWED = 3

  def self.current_cycle_for(user, time = Time.current)
    existing_cycle = user
      .support_call_cycles
      .current_for_time(time)
      .order(cycle_start_at: :desc)
      .first

    return existing_cycle if existing_cycle.present?

    cycle_start_at = time.beginning_of_month
    cycle_end_at = time.end_of_month

    cycle = user.support_call_cycles.create!(
      calls_allowed: DEFAULT_CALLS_ALLOWED,
      calls_used: 0,
      cycle_start_at: cycle_start_at,
      cycle_end_at: cycle_end_at
    )

    sync_ringcentral_unblock_for_new_cycle(user, cycle)

    cycle
  end

  def self.sync_ringcentral_unblock_for_new_cycle(user, cycle)
    return if user.phone.blank?

    result = Ringcentral::SyncBlockedCaller.call(user, cycle.cycle_start_at)

    Rails.logger.info(
      "[SupportCallCycleService] RingCentral unblock sync after new cycle " \
      "user_id=#{user.id} cycle_id=#{cycle.id} result=#{result.inspect}"
    )

    result
  rescue StandardError => e
    Rails.logger.error(
      "[SupportCallCycleService] RingCentral unblock sync failed " \
      "user_id=#{user.id} cycle_id=#{cycle&.id} #{e.class}: #{e.message}"
    )
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    nil
  end

  private_class_method :sync_ringcentral_unblock_for_new_cycle
end