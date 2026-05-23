module Ringcentral
  class ProcessInboundCallEvent
    ACTIONABLE_STATUSES = ["Setup", "Proceeding"].freeze

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      return skip!("not_inbound") unless event.direction == "Inbound"
      return skip!("not_actionable_status") unless ACTIONABLE_STATUSES.include?(event.status)
      return skip!("missing_telephony_session_id") if event.telephony_session_id.blank?
      return skip!("missing_party_id") if event.party_id.blank?
      return skip!("missing_caller_phone") if event.caller_phone.blank?

      existing_session = SupportCallSession.find_by(
        ringcentral_telephony_session_id: event.telephony_session_id,
        ringcentral_party_id: event.party_id
      )

      if existing_session.present?
        return skip!("duplicate_already_has_session")
      end

      user = User.find_by(phone: event.caller_phone)

      unless user.present?
        create_blocked_session!(nil, nil, "unknown_phone")
        return processed!("blocked_unknown_phone")
      end

      unless user.status == "active"
        create_blocked_session!(user, nil, "inactive_user")
        return processed!("blocked_inactive_user")
      end

      unless user.phone_verified_at.present?
        create_blocked_session!(user, nil, "phone_not_verified")
        return processed!("blocked_phone_not_verified")
      end

      cycle = current_call_cycle_for(user)

      unless cycle.present?
        create_blocked_session!(user, nil, "no_current_call_cycle")
        return processed!("blocked_no_current_call_cycle")
      end

      unless cycle.calls_used < cycle.calls_allowed
        create_blocked_session!(user, cycle, "no_calls_remaining")
        return processed!("blocked_no_calls_remaining")
      end

      create_allowed_session!(user, cycle)
      processed!("allowed_pending_forward")
    rescue => e
      Rails.logger.error("[RingCentral Processor] FAILED event_id=#{event.id} #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "error_#{e.class.name}"
      )

      false
    end

    private

    attr_reader :event

    def current_call_cycle_for(user)
      user.support_call_cycles
        .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
        .order(cycle_start_at: :desc)
        .first
    end

    def create_allowed_session!(user, cycle)
      SupportCallSession.create!(
        user: user,
        support_call_cycle: cycle,
        status: "allowed_pending_forward",
        started_at: Time.current,
        chargeable: false,
        ringcentral_telephony_session_id: event.telephony_session_id,
        ringcentral_party_id: event.party_id,
        ringcentral_status: event.status,
        caller_phone: event.caller_phone,
        to_phone: event.to_phone,
        ringcentral_extension_id: event.extension_id,
        ringcentral_to_name: event.to_name,
        ringcentral_raw_payload: event.raw_payload
      )
    end

    def create_blocked_session!(user, cycle, reason)
      SupportCallSession.create!(
        user: user,
        support_call_cycle: cycle,
        status: "blocked",
        started_at: Time.current,
        chargeable: false,
        blocked_reason: reason,
        ringcentral_telephony_session_id: event.telephony_session_id,
        ringcentral_party_id: event.party_id,
        ringcentral_status: event.status,
        caller_phone: event.caller_phone,
        to_phone: event.to_phone,
        ringcentral_extension_id: event.extension_id,
        ringcentral_to_name: event.to_name,
        ringcentral_raw_payload: event.raw_payload
      )
    end

    def processed!(result)
      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: result
      )

      Rails.logger.info("[RingCentral Processor] processed event_id=#{event.id} result=#{result}")
      true
    end

    def skip!(reason)
      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "skipped_#{reason}"
      )

      Rails.logger.info("[RingCentral Processor] skipped event_id=#{event.id} reason=#{reason}")
      false
    end
  end
end