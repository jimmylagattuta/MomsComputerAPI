# app/services/ask_mom/guardrails.rb
# frozen_string_literal: true

module AskMom
  class Guardrails
    # Only phrases that strongly indicate the user is genuinely stuck / not progressing.
    # IMPORTANT: Do NOT include normal follow-up prompts like:
    # - "now what", "what next", "what do i do", "help me"
    # The LLM can handle those without showing the contact panel.
    STUCK_PHRASES = [
      "i don't understand",
      "i dont understand",
      "i don't get it",
      "i dont get it",
      "confused",
      "i'm stuck",
      "im stuck",
      "still not working",
      "same thing",
      "doesn't work",
      "doesnt work",
      "does not work",
      "its not working",
      "it's not working"
    ].freeze

    DEFAULTS = {
      max_text_chars: 2500,
      max_user_per_60s: 12,
      max_llm_calls: 40,
      max_llm_calls_high: 18,

      # Panel trigger rule:
      # - only show if user appears genuinely stuck >=3 times within last 10 user turns (including current)
      stuck_within_last_user_turns: 10,
      stuck_min_hits: 3,

      # Repeat-loop is treated as "1 stuck hit" (still needs 3 total hits)
      repeat_within_last_user_turns: 3,
      repeat_min_matches: 2,

      # If true, allow panel as a "bail out" when the LLM budget is hit.
      # If you want STRICT "panel only for stuck/confused", set this to false.
      show_panel_on_llm_budget: true
    }.freeze

    def initialize(conversation:, new_user_text:, risk_level:, settings: {})
      @conversation = conversation
      @new_user_text = new_user_text.to_s
      @risk_level = (risk_level || "low").to_s
      @settings = DEFAULTS.merge(settings || {})
    end

    def check
      # IMPORTANT:
      # We evaluate "stuck" FIRST so rate limits / budget checks don't accidentally
      # suppress the contact panel when the user is clearly stuck.

      if stuck_hit_count >= @settings[:stuck_min_hits].to_i
        return allow_with_panel!("stuck")
      end

      # 1) hard ceilings (can block) — do NOT automatically show panel except optional llm_budget.
      if @new_user_text.length > @settings[:max_text_chars]
        return block!("too_long", "Your message is a bit long for me to safely process in one go.", show_panel: false)
      end

      if user_messages_in_last_60s >= @settings[:max_user_per_60s]
        return block!("rate_limited", "I might be missing details because messages are coming in fast.", show_panel: false)
      end

      if llm_calls_count >= llm_limit
        show_panel = !!@settings[:show_panel_on_llm_budget]
        return block!(
          "llm_budget",
          "We’ve done a lot of back-and-forth on this and I don’t want to spin our wheels.",
          show_panel: show_panel
        )
      end

      allow
    end

    private

    def allow
      { block: false, show_contact_panel: false, reason: nil }
    end

    def allow_with_panel!(reason)
      { block: false, show_contact_panel: true, reason: reason }
    end

    def block!(reason, friendly_message, show_panel:)
      {
        block: true,
        show_contact_panel: !!show_panel,
        reason: reason,
        friendly_message: friendly_message
      }
    end

    def high_risk?
      @risk_level == "high"
    end

    def llm_limit
      high_risk? ? @settings[:max_llm_calls_high] : @settings[:max_llm_calls]
    end

    def llm_calls_count
      @conversation.messages.where(sender_type: "ai").count
    rescue
      @conversation.messages.where(role: "assistant").count
    end

    def user_messages_in_last_60s
      @conversation.messages
                   .where(sender_type: "user")
                   .where("created_at >= ?", 60.seconds.ago)
                   .count
    rescue
      @conversation.messages
                   .where(role: "user")
                   .where("created_at >= ?", 60.seconds.ago)
                   .count
    end

    # Normalization used for BOTH incoming text and phrase matching.
    # Note: this makes "I don’t understand" (curly apostrophe) match "i don't understand".
    def normalize_text(s)
      s.to_s.downcase
       .gsub(/[^a-z0-9\s]/, " ")
       .gsub(/\s+/, " ")
       .strip
    end

    def normalized_stuck_phrases
      @normalized_stuck_phrases ||= STUCK_PHRASES.map { |p| normalize_text(p) }.reject(&:empty?)
    end

    # Fetch last N user messages (newest first).
    def fetch_recent_user_texts(n)
      n = n.to_i
      return [] if n <= 0

      @conversation.messages
                   .where(sender_type: "user")
                   .order(created_at: :desc)
                   .limit(n)
                   .pluck(:content)
    rescue
      @conversation.messages
                   .where(role: "user")
                   .order(created_at: :desc)
                   .limit(n)
                   .pluck(:content)
    end

    # "Repeat loop" = same exact message sent repeatedly (>=2 times in last 3 prior user turns)
    def repeated_text_loop?
      n = @settings[:repeat_within_last_user_turns].to_i
      normalized_new = normalize_text(@new_user_text)
      return false if normalized_new.empty? || n <= 0

      recent = fetch_recent_user_texts(n + 1).map { |t| normalize_text(t) }.reject(&:empty?)

      # If controller already saved the current message, the newest saved will match normalized_new.
      recent.shift if recent.first == normalized_new

      recent.take(n).count { |t| t == normalized_new } >= @settings[:repeat_min_matches].to_i
    end

    # Count stuck signals in the last N user turns INCLUDING current.
    # Also: if repeat-loop triggers, add +1 hit (still needs 3 total hits to show panel).
    def stuck_hit_count
      n = @settings[:stuck_within_last_user_turns].to_i
      min_hits = @settings[:stuck_min_hits].to_i
      return 0 if n <= 0 || min_hits <= 0

      normalized_new = normalize_text(@new_user_text)
      recent = fetch_recent_user_texts(n).map { |t| normalize_text(t) }.reject(&:empty?)

      # If controller saved the current message already, drop it so we don't double-count.
      recent.shift if recent.first == normalized_new

      window = recent.take(n - 1)
      window << normalized_new

      return 0 if window.length < min_hits

      phrase_hits =
        window.count do |t|
          normalized_stuck_phrases.any? { |p| !p.empty? && t.include?(p) }
        end

      repeat_hit = repeated_text_loop? ? 1 : 0
      phrase_hits + repeat_hit
    end
  end
end
