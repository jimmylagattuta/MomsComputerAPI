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

      user = find_user_by_phone(event.caller_phone)

      # Important business rule:
      # Unknown callers are public office callers, not app users.
      # Let RingCentral's normal office routing continue.
      unless user.present?
        return passthrough_without_session!("unknown_phone")
      end

      # Known app user, but not allowed to use app-based call access.
      unless user.status == "active"
        return blocked_without_session!("inactive_user")
      end

      unless user.phone_verified_at.present?
        return blocked_without_session!("phone_not_verified")
      end

      cycle = current_call_cycle_for(user)

      unless cycle.present?
        return blocked_without_session!("no_current_call_cycle")
      end

      unless cycle.calls_used < cycle.calls_allowed
        create_blocked_session!(user, cycle, "no_calls_remaining")
        return processed!("blocked_no_calls_remaining")
      end

      create_allowed_passthrough_session!(user, cycle)
      processed!("allowed_passthrough_known_user")
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

    def find_user_by_phone(phone)
      User.find_by(phone: phone)
    end

    def current_call_cycle_for(user)
      user.support_call_cycles
        .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
        .order(cycle_start_at: :desc)
        .first
    end

    def create_allowed_passthrough_session!(user, cycle)
      SupportCallSession.create!(
        user: user,
        support_call_cycle: cycle,
        status: "allowed_passthrough",
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

    def passthrough_without_session!(reason)
      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "passthrough_#{reason}"
      )

      Rails.logger.info(
        "[RingCentral Processor] passthrough_without_session " \
        "event_id=#{event.id} reason=#{reason} caller_phone=#{event.caller_phone}"
      )

      true
    end

    def blocked_without_session!(reason)
      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "blocked_#{reason}"
      )

      Rails.logger.info(
        "[RingCentral Processor] blocked_without_session " \
        "event_id=#{event.id} reason=#{reason} caller_phone=#{event.caller_phone}"
      )

      true
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