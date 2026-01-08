# app/services/sensitive_data_redactor.rb
class SensitiveDataRedactor
  # Goal: do NOT store raw sensitive numbers.
  # We only detect obvious patterns. This isn't perfect, but it’s a strong guardrail.

  CREDIT_CARD_REGEX = /\b(?:\d[ -]*?){13,19}\b/
  SSN_REGEX         = /\b\d{3}-?\d{2}-?\d{4}\b/
  # Bank accounts vary hugely; we avoid false positives by only flagging when user mentions "account" nearby
  BANK_KEYWORDS     = /(account|routing|aba|iban|swift)/i
  LONG_NUMBER_REGEX = /\b\d{8,}\b/

  def self.contains_sensitive?(text)
    return false if text.blank?
    t = text.to_s

    credit_card_like?(t) || ssn_like?(t) || bank_account_like?(t)
  end

  def self.redact(text)
    return "" if text.blank?
    t = text.to_s.dup

    t.gsub!(SSN_REGEX, "[REDACTED_SSN]")
    t.gsub!(CREDIT_CARD_REGEX) { |m| luhn_valid?(digits_only(m)) ? "[REDACTED_CARD]" : m }
    t = redact_bankish_numbers(t)

    t
  end

  def self.reasons(text)
    return [] if text.blank?
    t = text.to_s
    reasons = []
    reasons << "ssn" if ssn_like?(t)
    reasons << "credit_card" if credit_card_like?(t)
    reasons << "bank_account" if bank_account_like?(t)
    reasons.uniq
  end

  def self.ssn_like?(t)
    t.match?(SSN_REGEX)
  end

  def self.credit_card_like?(t)
    candidates = t.scan(CREDIT_CARD_REGEX)
    candidates.any? { |m| luhn_valid?(digits_only(m)) }
  end

  def self.bank_account_like?(t)
    # Conservative: require a keyword AND a long number
    t.match?(BANK_KEYWORDS) && t.match?(LONG_NUMBER_REGEX)
  end

  def self.redact_bankish_numbers(t)
    return t unless bank_account_like?(t)

    # Redact long numbers ONLY if keyword present somewhere in the text
    t.gsub(LONG_NUMBER_REGEX) do |m|
      m.length >= 8 ? "[REDACTED_NUMBER]" : m
    end
  end

  def self.digits_only(str)
    str.to_s.gsub(/\D/, "")
  end

  # Luhn algorithm for card validation
  def self.luhn_valid?(digits)
    return false if digits.blank?
    return false unless digits.length.between?(13, 19)
    return false unless digits.match?(/\A\d+\z/)

    sum = 0
    digits.chars.reverse.each_with_index do |ch, idx|
      n = ch.to_i
      if idx.odd?
        n *= 2
        n -= 9 if n > 9
      end
      sum += n
    end
    (sum % 10).zero?
  end
end