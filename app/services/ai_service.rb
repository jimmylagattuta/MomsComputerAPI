# app/services/ai_service.rb
class AiService
  # Returns a structured hash:
  # {
  #   risk_level: "low"|"medium"|"high",
  #   summary: String,
  #   steps: Array<String>,
  #   escalate_suggested: Boolean,
  #   confidence: Float (0..1),
  #   model: String,
  #   prompt_version: String,
  #   llm_recommended: Boolean,
  #   llm_reason: String
  # }
  def self.call(user:, text:, context: nil)
    t_raw = text.to_s
    t = normalize(t_raw)

    convo_id = context.is_a?(Hash) ? context[:conversation_id] : nil
    user_id = user&.id

    # 1) High-risk scam triggers (fast + blunt)
    high_triggers = [
      "gift card", "itunes", "google play", "steam card",
      "wire transfer", "western union", "moneygram",
      "crypto", "bitcoin", "ethereum",
      "remote access", "anydesk", "teamviewer", "logmein",
      "bank login", "routing number", "account number",
      "verification code", "2fa code", "one-time code", "otp",
      "refund department", "your computer is infected", "security alert",
      "call this number"
    ]

    if includes_any?(t, high_triggers)
      result = {
        risk_level: "high",
        summary: "Stop right there. This looks scammy. Do NOT pay, do NOT share codes/passwords, and do NOT allow remote access.",
        steps: [
          "Do not buy gift cards, do not wire money, and do not send crypto.",
          "Do not call any number shown on a pop-up or email.",
          "Close the page/app and tell me the *exact* words you saw.",
          "If you already shared a password/code, change the password immediately and contact your bank/provider."
        ],
        escalate_suggested: true,
        confidence: 0.94,
        model: "stub",
        prompt_version: "v2_highrisk"
      }

      return attach_llm_recommendation(result, text: t_raw)
    end

    # 2) Greeting / low-signal / gibberish
    if GreetingDetector.greeting?(t_raw)
      result = GreetingDetector.response(
        user_id: user_id,
        conversation_id: convo_id,
        raw_text: t_raw
      )

      return attach_llm_recommendation(result, text: t_raw)
    end

    # 3) Common problem playbooks (cheap “AI” feel)
    intent = ProblemPlaybooks.detect_intent(t)
    if intent
      resp = ProblemPlaybooks.response_for(
        intent: intent,
        user_id: user_id,
        conversation_id: convo_id,
        raw_text: t_raw
      )

      if resp
        return attach_llm_recommendation(resp, text: t_raw)
      end
    end

    # 4) Default: helpful troubleshooting guidance (also varied)
    result = default_response(
      user_id: user_id,
      conversation_id: convo_id,
      raw_text: t_raw
    )

    attach_llm_recommendation(result, text: t_raw)
  end

  def self.default_response(user_id:, conversation_id:, raw_text:)
    rng = Random.new((Time.now.to_i + rand(1_000_000)) & 0x7fffffff)

    openers = [
      "Got it. I can help you figure this out safely.",
      "Okay—tell me what’s happening and we’ll work it out.",
      "Alright. We’ll troubleshoot this the clean way.",
      "No problem. Give me the details and we’ll fix it.",
      "Okay—walk me through what you did, then what you saw."
    ]

    followups = [
      "What device are you using (iPhone/Android/Mac/Windows) and what app/site?",
      "What were you trying to do right before the problem happened?",
      "What does the screen say (exact words), and is anyone asking for money, codes, or remote access?",
      "Did this start after clicking a link or installing something?",
      "Is this happening on Wi-Fi, cellular, or both?"
    ]

    summary = "#{openers[rng.rand(openers.length)]} #{followups[rng.rand(followups.length)]}"

    steps_pool = [
      "Tell me the device (iPhone/Android/Mac/Windows).",
      "Tell me the app/site name.",
      "Paste the exact error message or describe it.",
      "Tell me the last thing you clicked.",
      "If it mentions money/codes/remote access, stop and tell me exactly what it asked for."
    ]

    steps = steps_pool.shuffle(random: rng).take(3 + rng.rand(3))
    steps << "If you can, type the exact wording from the screen—one line at a time."

    {
      risk_level: "medium",
      summary: summary,
      steps: steps,
      escalate_suggested: false,
      confidence: 0.78,
      model: "stub",
      prompt_version: "v4_default_variants"
    }
  end

  # ----------------------------
  # LLM recommendation (NO LLM CALL)
  # ----------------------------
  #
  # This is dev-focused routing metadata so we can:
  # - pop an alert in the app ("LLM would trigger: reason")
  # - log it
  # - later, swap in a real provider only when warranted
  #
  # It never changes the user-facing response by itself.
  def self.attach_llm_recommendation(result, text:)
    r = (result || {}).dup

    # Normalize expected keys just in case
    risk = r[:risk_level].to_s
    conf = r[:confidence].to_f
    raw = text.to_s

    decision = llm_decision(text: raw, risk_level: risk, confidence: conf)

    r[:llm_recommended] = decision[:recommended]
    r[:llm_reason] = decision[:reason]

    r
  end

  def self.llm_decision(text:, risk_level:, confidence:)
    t = text.to_s.strip
    down = t.downcase

    # Rules-first always handles obvious high-risk
    return { recommended: false, reason: "high_risk_rules", confidence: confidence } if risk_level == "high"

    reasons = []

    # Big blob -> LLM helps summarization/extraction
    reasons << "long_message" if t.length >= 400

    # Ambiguous: short-ish but not confidently handled
    reasons << "low_confidence" if confidence < 0.72

    # Troubleshooting domains where reasoning helps (cheap heuristic)
    complex_terms = %w[
      certificate firewall port dns router vpn printer outlook gmail
      imap smtp ssl tls driver update malware popup subscription
    ]
    reasons << "complex_terms" if complex_terms.any? { |w| down.include?(w) }

    # User pastes “exact error style” strings
    reasons << "looks_like_error_log" if looks_like_error_log?(t)

    # If it’s a greeting/low-signal, never recommend LLM (we handle it cheap)
    if risk_level == "low" && t.length <= 120
      reasons = reasons - ["low_confidence"]
    end

    {
      recommended: reasons.any?,
      reason: reasons.any? ? reasons.join(",") : "not_needed",
      confidence: confidence
    }
  end

  def self.looks_like_error_log?(t)
    s = t.to_s
    return false if s.length < 20

    # crude but useful patterns
    return true if s.match?(/error\s*\d+/i)
    return true if s.match?(/\b(exception|stack trace|traceback)\b/i)
    return true if s.count(":") >= 4 && s.count("/") >= 2
    return true if s.match?(/\b0x[0-9a-f]+\b/i)
    false
  end

  # ----------------------------
  # Helpers
  # ----------------------------
  def self.normalize(s)
    s.to_s.downcase
      .gsub(/[“”]/, '"')
      .gsub(/[‘’]/, "'")
      .gsub(/[^a-z0-9\s\?\!\.\,\-]/, " ")
      .gsub(/\s+/, " ")
      .strip
  end

  def self.includes_any?(t, arr)
    arr.any? { |x| t.i
