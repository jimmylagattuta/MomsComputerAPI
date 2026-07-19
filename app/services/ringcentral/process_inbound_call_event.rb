module Ringcentral
  class ProcessInboundCallEvent
    ACTIONABLE_STATUSES = ["Setup", "Proceeding"].freeze

    # Comma-separated Heroku config:
    # RINGCENTRAL_ALWAYS_ALLOWED_CALLERS="+18002810692,+13106637276"
    #
    # The main office number is included as a safe default so it cannot
    # accidentally be treated as an unknown app caller.
    DEFAULT_ALWAYS_ALLOWED_CALLERS = ["+18002810692"].freeze

    ANSWERABLE_SESSION_STATUSES = [
      "allowed_passthrough",
      "allowed_pending_forward",
      "reconnect_buffer",
      "forwarded",
      "in_progress",
      "completed"
    ].freeze

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      # RingCentral may send Answered after Setup/Proceeding.
      # Answered should mark the session as connected, but must not charge yet.
      if event.status == "Answered"
        return handle_answered_event!
      end

      # Disconnected should end the session.
      # If this was answered, it starts the 15-minute delayed-charge window.
      if event.status == "Disconnected"
        return handle_disconnected_event!
      end

      return skip!("not_inbound") unless event.direction == "Inbound"
      return skip!("not_actionable_status") unless ACTIONABLE_STATUSES.include?(event.status)
      return skip!("missing_telephony_session_id") if event.telephony_session_id.blank?
      return skip!("missing_party_id") if event.party_id.blank?
      return skip!("missing_caller_phone") if event.caller_phone.blank?

      # Trusted business/administrative numbers must always pass through.
      # They are not app users and must never be disconnected as unknown callers,
      # consume support-call credits, or create support-call sessions.
      if always_allowed_caller?(event.caller_phone)
        Rails.logger.info(
          "[RingCentral Processor] always-allowed caller bypass " \
          "event_id=#{event.id} " \
          "caller_phone=#{event.caller_phone} " \
          "normalized_caller_phone=#{normalize_phone(event.caller_phone)}"
        )

        return passthrough_without_session!("always_allowed_caller")
      end

      existing_session = find_existing_session

      if existing_session.present?
        update_existing_session_from_event!(existing_session)
        return processed!("existing_session_updated")
      end

      user = find_user_by_phone(event.caller_phone)

      # Direct-dial support calls should only reach support when the caller is
      # a known, active, phone-verified, subscribed app user.
      #
      # Unknown callers should not bypass the app by dialing the RingCentral
      # number directly.
      unless user.present?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("unknown_phone", enforcement_result)
      end

      unless user.status == "active"
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("inactive_user", enforcement_result)
      end

      unless user.phone_verified_at.present?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("phone_not_verified", enforcement_result)
      end

      unless user.support_subscription_active?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("not_subscribed", enforcement_result)
      end

      cycle = current_call_cycle_for(user)

      unless cycle.present?
        enforcement_result = enforce_blocked_call!
        return blocked_without_session!("no_current_call_cycle", enforcement_result)
      end

      if cycle.calls_used >= cycle.calls_allowed
        active_buffer_session = active_reconnect_buffer_session_for(user)

        if active_buffer_session.present?
          create_reconnect_buffer_session!(user, cycle, active_buffer_session)
          return processed!("allowed_reconnect_buffer")
        end

        session = create_blocked_session!(user, cycle, "no_calls_remaining")
        enforcement_result = enforce_blocked_call!

        session.update!(
          failure_reason:
            if enforcement_result[:success]
              "ringcentral_enforcement_success"
            else
              "ringcentral_enforcement_failed"
            end
        )

        return processed!(
          if enforcement_result[:success]
            "blocked_no_calls_remaining_enforced"
          else
            "blocked_no_calls_remaining_enforcement_failed"
          end
        )
      end

      create_allowed_passthrough_session!(user, cycle)
      processed!("allowed_passthrough_known_user")
    rescue ActiveRecord::RecordInvalid => e
      # RingCentral can deliver duplicate Setup/Proceeding events very close
      # together, especially if duplicate subscriptions exist. If another event
      # already created the session, treat this event as an idempotent update
      # instead of a hard failure.
      existing_session = find_existing_session

      if existing_session.present?
        update_existing_session_from_event!(existing_session)
        return processed!("existing_session_updated_after_duplicate_create")
      end

      handle_error(e)
    rescue StandardError => e
      handle_error(e)
    end

    private

    attr_reader :event

    def always_allowed_caller?(phone)
      normalized_caller = normalize_phone(phone)
      return false if normalized_caller.blank?

      always_allowed_callers.include?(normalized_caller)
    end

    def always_allowed_callers
      @always_allowed_callers ||= begin
        configured_numbers =
          ENV.fetch("RINGCENTRAL_ALWAYS_ALLOWED_CALLERS", "")
             .split(",")
             .map(&:strip)
             .reject(&:blank?)

        (DEFAULT_ALWAYS_ALLOWED_CALLERS + configured_numbers)
          .map { |phone| normalize_phone(phone) }
          .reject(&:blank?)
          .uniq
      end
    end

    # Normalizes common US phone-number formats to E.164-style values.
    #
    # Examples:
    #   (800) 281-0692  -> +18002810692
    #   8002810692      -> +18002810692
    #   18002810692     -> +18002810692
    #   +18002810692    -> +18002810692
    def normalize_phone(phone)
      digits = phone.to_s.gsub(/\D/, "")
      return nil if digits.blank?

      if digits.length == 10
        "+1#{digits}"
      elsif digits.length == 11 && digits.start_with?("1")
        "+#{digits}"
      else
        "+#{digits}"
      end
    end

    def find_existing_session
      return nil if event.telephony_session_id.blank?

      exact_match =
        if event.party_id.present?
          SupportCallSession.find_by(
            ringcentral_telephony_session_id: event.telephony_session_id,
            ringcentral_party_id: event.party_id
          )
        end

      exact_match ||
        SupportCallSession
          .where(ringcentral_telephony_session_id: event.telephony_session_id)
          .order(created_at: :asc)
          .first
    end

    def find_user_by_phone(phone)
      normalized = phone.to_s.strip
      normalized_e164 = normalize_phone(phone)
      digits = normalized.gsub(/\D/, "")
      last_10 = digits.last(10)

      possible_numbers = [
        normalized,
        normalized_e164,
        normalized.delete_prefix("+1"),
        normalized.delete_prefix("+"),
        digits,
        last_10,
        last_10.present? ? "+1#{last_10}" : nil
      ].compact.uniq

      User.where(phone: possible_numbers).first
    end

    def current_call_cycle_for(user)
      user.support_call_cycles
        .where(
          "cycle_start_at <= ? AND cycle_end_at >= ?",
          Time.current,
          Time.current
        )
        .order(cycle_start_at: :desc)
        .first
    end

    def active_reconnect_buffer_session_for(user)
      user.support_call_sessions
        .where("buffer_expires_at > ?", Time.current)
        .order(buffer_expires_at: :desc)
        .first
    end

    def update_existing_session_from_event!(session)
      session.update!(
        ringcentral_status: event.status,
        caller_phone: event.caller_phone.presence || session.caller_phone,
        to_phone: event.to_phone.presence || session.to_phone,
        ringcentral_extension_id:
          event.extension_id.presence || session.ringcentral_extension_id,
        ringcentral_to_name:
          event.to_name.presence || session.ringcentral_to_name,
        ringcentral_raw_payload:
          event.raw_payload.presence || session.ringcentral_raw_payload
      )
    end

    def handle_answered_event!
      if event.telephony_session_id.blank?
        return skip!("answered_missing_telephony_session_id")
      end

      session = SupportCallSession
        .where(ringcentral_telephony_session_id: event.telephony_session_id)
        .where(status: ANSWERABLE_SESSION_STATUSES)
        .order(created_at: :asc)
        .first

      unless session.present?
        return skip!("answered_no_matching_allowed_session")
      end

      if session.blocked_reason.present?
        return skip!("answered_matching_session_was_blocked")
      end

      if session.charged?
        return skip!("answered_session_already_charged")
      end

      if session.answered_at.present?
        session.update!(ringcentral_status: event.status)

        Rails.logger.info(
          "[RingCentral Processor] answered duplicate ignored " \
          "event_id=#{event.id} session_id=#{session.id} " \
          "user_id=#{session.user_id} answered_at=#{session.answered_at}"
        )

        return processed!("answered_already_marked")
      end

      session.mark_answered!(ringcentral_status: event.status)

      Rails.logger.info(
        "[RingCentral Processor] marked session answered without charging " \
        "event_id=#{event.id} session_id=#{session.id} " \
        "user_id=#{session.user_id} answered_at=#{session.answered_at}"
      )

      processed!("answered_marked_pending_disconnect")
    end

    def handle_disconnected_event!
      if event.telephony_session_id.blank?
        return skip!("disconnected_missing_telephony_session_id")
      end

      session = SupportCallSession
        .where(ringcentral_telephony_session_id: event.telephony_session_id)
        .order(created_at: :asc)
        .first

      unless session.present?
        return skip!("disconnected_no_matching_session")
      end

      session.update!(
        ended_at: session.ended_at || Time.current,
        ringcentral_status: event.status
      )

      unless session.answered?
        Rails.logger.info(
          "[RingCentral Processor] disconnected unanswered session; " \
          "no charge scheduled event_id=#{event.id} session_id=#{session.id}"
        )

        return processed!("disconnected_unanswered_no_charge")
      end

      if session.charged?
        Rails.logger.info(
          "[RingCentral Processor] disconnected already charged session; " \
          "no new charge scheduled event_id=#{event.id} session_id=#{session.id}"
        )

        return processed!("disconnected_already_charged")
      end

      if session.buffer_expires_at.present?
        Rails.logger.info(
          "[RingCentral Processor] disconnected duplicate ignored; " \
          "reconnect buffer already exists event_id=#{event.id} " \
          "session_id=#{session.id} " \
          "buffer_expires_at=#{session.buffer_expires_at}"
        )

        return processed!("disconnected_already_has_reconnect_buffer")
      end

      session.mark_ended_and_start_reconnect_buffer!(
        ringcentral_status: event.status
      )
      session.schedule_delayed_charge!

      Rails.logger.info(
        "[RingCentral Processor] answered call ended; delayed charge scheduled " \
        "event_id=#{event.id} session_id=#{session.id} " \
        "buffer_expires_at=#{session.buffer_expires_at}"
      )

      Ringcentral::SyncBlockedCaller.call(session.user, Time.current)

      processed!("disconnected_answered_delayed_charge_scheduled")
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

    def create_reconnect_buffer_session!(user, cycle, active_buffer_session)
      SupportCallSession.create!(
        user: user,
        support_call_cycle: cycle,
        status: "reconnect_buffer",
        started_at: Time.current,
        chargeable: false,
        buffer_expires_at: active_buffer_session.buffer_expires_at,
        failure_reason: "active_reconnect_buffer",
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
        "[RingCentral Processor] drop_call_session failed; " \
        "trying reject_call_party event_id=#{event.id} " \
        "drop_result=#{drop_result.inspect}"
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
        "event_id=#{event.id} reason=#{reason} " \
        "caller_phone=#{event.caller_phone}"
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

      Rails.logger.info(
        "[RingCentral Processor] processed event_id=#{event.id} result=#{result}"
      )

      true
    end

    def skip!(reason)
      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "skipped_#{reason}"
      )

      Rails.logger.info(
        "[RingCentral Processor] skipped event_id=#{event.id} reason=#{reason}"
      )

      false
    end

    def handle_error(error)
      Rails.logger.error(
        "[RingCentral Processor] FAILED event_id=#{event.id} " \
        "#{error.class}: #{error.message}"
      )

      if error.backtrace.present?
        Rails.logger.error(error.backtrace.first(10).join("\n"))
      end

      event.update!(
        processed: true,
        processed_at: Time.current,
        processing_result: "error_#{error.class.name}"
      )

      false
    end
  end
end