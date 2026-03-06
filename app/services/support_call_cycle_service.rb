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

    user.support_call_cycles.create!(
      calls_allowed: DEFAULT_CALLS_ALLOWED,
      calls_used: 0,
      cycle_start_at: cycle_start_at,
      cycle_end_at: cycle_end_at
    )
  end
end