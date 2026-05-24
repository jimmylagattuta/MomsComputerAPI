module Ringcentral
  class ProcessInboundCallEvent
    ACTIONABLE_STATUSES = ["Setup", "Proceeding"].freeze
    CHARGEABLE_ALLOWED_STATUSES = [
      "allowed_passthrough",
      "allowed_pending_forward",
      "forwarded",
      "in_progress"
    ].freeze

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      # RingCentral may send Answered as an Outbound mirror event.
      # Handle Answered before the inbound/actionable-status skips.
      if event.status == "Answered"
        return handle_answered_event!
      end

      return skip!("not_inbound") unless event.direction == "Inbound"
      return skip!("not_actionable_status") unless ACTIONABLE_STATUSES.include?(event.status)
      return skip!("missing_telephony_session_id") if event.telephony_session_id.blank?
      return skip!("missing_party_id") if event.party_id.blank?
      return skip!("missing_caller_phone") if event.caller_phone.blank?

      # IMPORTANT:
      # RingCentral sends multiple party IDs for the same call because the call
      # hits MOM's buffer / queue routing. We only want one support session and
      # one enforcement attempt per telephony_session_id.
      existing_session = SupportCallSession.find_by(
        ringcentral_telephony_session_id: event.telephony_session_id
      )

      if existing_session.present?
        return skip!("duplicate_already_has_session")
      end

      user = find_user_by_phone(event.caller_phone)

      # Public office callers are not app users.
      # Unknown numbers should pass through to the normal RingCentral office routing.
      unless user.present?
        return passthrough_without_session!("unknown_phone")
      end

      unless user.status == "active"
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("inactive_user", enforcement_result)
      end

      unless user.phone_verified_at.present?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("phone_not_verified", enforcement_result)
      end

      cycle = current_call_cycle_for(user)

      unless cycle.present?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("no_current_call_cycle", enforcement_result)
      end

      unless cycle.calls_used < cycle.calls_allowed
        session = create_blocked_session!(user, cycle, "no_calls_remaining")
        enforcement_result = enforce_blocked_call!

        session.update!(
          failure_reason: enforcement_result[:success] ? "ringcentral_enforcement_success" : "ringcentral_enforcement_failed"
        )

        return processed!(
          enforcement_result[:success] ? "blocked_no_calls_remaining_enforced" : "blocked_no_calls_remaining_enforcement_failed"
        )
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
      normalized = phone.to_s.strip
      digits = normalized.gsub(/\D/, "")
      last_10 = digits.last(10)

      possible_numbers = [
        normalized,
        normalized.delete_prefix("+1"),
        normalized.delete_prefix("+"),
        digits,
        last_10,
        "+1#{last_10}"
      ].compact.uniq

      User.where(phone: possible_numbers).first
    end

    def current_call_cycle_for(user)
      user.support_call_cycles
        .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
        .order(cycle_start_at: :desc)
        .first
    end

    def handle_answered_event!
      return skip!("answered_missing_telephony_session_id") if event.telephony_session_id.blank?

      session = SupportCallSession
        .where(ringcentral_telephony_session_id: event.telephony_session_id)
        .where(status: CHARGEABLE_ALLOWED_STATUSES)
        .order(created_at: :asc)
        .first

      unless session.present?
        return skip!("answered_no_matching_allowed_session")
      end

      if session.chargeable?
        return skip!("answered_session_already_chargeable")
      end

      session.update!(
        status: "in_progress",
        answered_at: Time.current,
        ringcentral_status: event.status
      )

      # This increments calls_used once through SupportCallSession#mark_chargeable!.
      # The model already protects against double-charging with return if chargeable?.
      session.mark_chargeable!(duration: 0)

      processed!("answered_charged_call")
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

    def enforce_blocked_call!
      drop_result = Ringcentral::DropCallSession.call(event)

      return drop_result if drop_result[:success]

      Rails.logger.info(
        "[RingCentral Processor] drop_call_session failed; trying reject_call_party " \
        "event_id=#{event.id} drop_result=#{drop_result.inspect}"
      )

      reject_result = Ringcentral::RejectCallParty.call(event)

      {
        success: reject_result[:success],
        primary_action: "drop_call_session",
        fallback_action: "reject_call_party",
        drop_result: drop_result,
        reject_result: reject_result
      }
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

    def blocked_without_session!(reason, enforcement_result = nil)
      suffix =
        if enforcement_result.nil?
          nil
        elsif enforcement_result[:success]
          "enforced"
        else
          "enforcement_failed"
        end

      result = ["blocked_#{reason}", suffix].compact.join("_")

      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: result
      )

      Rails.logger.info(
        "[RingCentral Processor] blocked_without_session " \
        "event_id=#{event.id} reason=#{reason} " \
        "caller_phone=#{event.caller_phone} " \
        "enforcement_result=#{enforcement_result.inspect}"
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