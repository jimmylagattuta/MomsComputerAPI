# app/services/ai_service.rb
class AiService
  # Stub for now. Swap later for OpenAI / your provider.
  # Should return a structured hash:
  # { risk_level:, summary:, steps:, escalate_suggested:, confidence: }

  def self.call(user:, text:, context: nil)
    # Very basic heuristic stub
    t = text.to_s.downcase

    high_triggers = [
      "gift card", "wire", "western union", "bitcoin", "crypto",
      "remote access", "anydesk", "teamviewer", "logmein",
      "verify your account", "password", "bank", "routing", "ssn",
      "irs", "refund", "suspended", "security alert"
    ]

    risk = high_triggers.any? { |w| t.include?(w) } ? "high" : "medium"

    steps = if risk == "high"
      [
        "Do not send money or gift cards.",
        "Do not share passwords or verification codes.",
        "If someone is on your screen, disconnect from the internet and restart your device.",
        "Use the Call Mom button if you feel unsure."
      ]
    else
      [
        "Do not click any links you don’t recognize.",
        "If you already clicked, restart your device.",
        "If you want, forward the message or screenshot to Mom for review."
      ]
    end

    {
      risk_level: risk,
      summary: risk == "high" ? "This looks like a high-risk scam." : "This may be suspicious.",
      steps: steps,
      escalate_suggested: (risk == "high"),
      confidence: (risk == "high" ? 0.75 : 0.55)
    }
  end
end