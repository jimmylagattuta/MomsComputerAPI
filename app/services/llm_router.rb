# app/services/llm_router.rb
class LlmRouter
  # returns { recommended: boolean, reason: string, confidence: float }
  def self.decide(text:, risk_level:, base_confidence:)
    t = text.to_s.strip

    # never for obvious greeting/high-risk handled paths
    return { recommended: false, reason: "handled_by_rules", confidence: base_confidence } if risk_level == "low" && t.length <= 80

    reasons = []

    # very long / “blob”
    reasons << "long_message" if t.length >= 400

    # ambiguous: short but not greeting, not scam triggers
    reasons << "ambiguous_short" if t.length.between?(10, 80) && base_confidence < 0.78

    # complex-ish hints (cheap heuristic)
    complex_terms = %w[certificate firewall port dns router vpn printer outlook gmail imap smtp ssl tls driver]
    reasons << "complex_terms" if complex_terms.any? { |w| t.downcase.include?(w) }

    recommended = reasons.any?
    reason = recommended ? reasons.join(",") : "not_needed"

    {
      recommended: recommended,
      reason: reason,
      confidence: base_confidence
    }
  end
end
