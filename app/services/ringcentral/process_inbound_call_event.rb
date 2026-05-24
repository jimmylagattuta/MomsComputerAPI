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

      # Public office callers are not app users.
      # Unknown numbers should pass through to the normal RingCentral office routing.
      unless user.present?
        return passthrough_without_session!("unknown_phone")
      end

      unless user.status == "active"
        reject_result = reject_call!
        return blocked_without_session!("inactive_user", reject_result)
      end

      unless user.phone_verified_at.present?
        reject_result = reject_call!
        return blocked_without_session!("phone_not_verified", reject_result)
      end

      cycle = current_call_cycle_for(user)

      unless cycle.present?
        reject_result = reject_call!
        return blocked_without_session!("no_current_call_cycle", reject_result)
      end

      unless cycle.calls_used < cycle.calls_allowed
        session = create_blocked_session!(user, cycle, "no_calls_remaining")
        reject_result = reject_call!

        session.update!(
          failure_reason: reject_result[:success] ? "ringcentral_reject_success" : "ringcentral_reject_failed"
        )

        return processed!(
          reject_result[:success] ? "blocked_no_calls_remaining_rejected" : "blocked_no_calls_remaining_reject_failed"
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

      possible_numbers = [
        normalized,
        normalized.delete_prefix("+1"),
        normalized.delete_prefix("+"),
        normalized.gsub(/\D/, ""),
        "+1#{normalized.gsub(/\D/, "").last(10)}"
      ].uniq

      User.where(phone: possible_numbers).first
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

    def reject_call!
      Ringcentral::RejectCallParty.call(event)
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

    def blocked_without_session!(reason, reject_result = nil)
      suffix =
        if reject_result.nil?
          nil
        elsif reject_result[:success]
          "rejected"
        else
          "reject_failed"
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
        "reject_result=#{reject_result.inspect}"
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