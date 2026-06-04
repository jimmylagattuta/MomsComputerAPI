# app/services/ask_mom/public_responder.rb
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module AskMom
  class PublicResponder
    def initialize(text:, image_urls: [])
      @text = text.to_s
      @image_urls = Array(image_urls).compact
    end

    def call
      pre_risk_level = compute_risk_level_pre_llm(@text)

      if pre_risk_level == "high"
        return {
          risk_level: "high",
          title: "Possible scam",
          summary: "Stop here. This has scam warning signs, especially if money, codes, gift cards, crypto, or remote access are involved.",
          steps: [
            "Do not send money, gift cards, crypto, passwords, or verification codes.",
            "Do not install remote-access apps like AnyDesk or TeamViewer.",
            "Take a screenshot and get with a trusted person before doing anything."
          ],
          escalate_suggested: true,
          confidence: 0.94,
          show_contact_panel: false,
          escalation_reason: nil,
          model: "rules",
          prompt_version: "public_rules_v1"
        }
      end

      ask_llm
    end

    private

    def compute_risk_level_pre_llm(text)
      t = text.to_s.downcase

      high_hits = [
        "gift card",
        "wire money",
        "bank transfer",
        "zelle",
        "venmo",
        "cash app",
        "crypto",
        "bitcoin",
        "refund",
        "remote access",
        "anydesk",
        "teamviewer",
        "screenconnect",
        "login code",
        "verification code",
        "ssn",
        "social security",
        "bank account",
        "routing number"
      ]

      return "high" if high_hits.any? { |k| t.include?(k) }

      "low"
    end

    def ask_llm
      api_key = ENV["OPENAI_API_KEY"].to_s
      raise "Missing OPENAI_API_KEY" if api_key.empty?

      model = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
      timeout = ENV.fetch("OPENAI_TIMEOUT", "20").to_i

      instructions = <<~TXT
        You are "Mom's Computer" — a warm-but-no-nonsense scam-safety and tech-help assistant for seniors.

        PUBLIC GUEST MODE:
        The user is not signed in.
        Do not mention saved history.
        Do not claim you can call, text, or email support for them.
        Call Mom, Text Mom, and Email Mom are locked unless the user creates an account and subscribes.

        SECURITY:
        Never ask for passwords, login codes, SSN, bank numbers, card numbers, or full identity details.
        If money, gift cards, crypto, bank transfer, login codes, or remote access are involved, tell the user to stop.

        IMAGES:
        If images are attached, you can see them.
        If image-only, describe what looks important or suspicious and ask one clarifying question.

        STYLE:
        Simple words.
        Short sentences.
        Calm, protective, practical.
        Ask at most one question.
        Keep summary 1-2 sentences.
        Use 0-4 short steps.

        OUTPUT:
        Return valid JSON only.
        Keys:
        risk_level: "low" | "medium" | "high"
        title: short title
        summary: string
        steps: array
        escalate_suggested: boolean
        confidence: number 0..1
      TXT

      user_prompt_text =
        if @text.strip.empty?
          "The user sent only image(s). Analyze the image(s). Tell them what looks important or suspicious, and what to do next."
        else
          @text
        end

      content_parts = [
        {
          type: "input_text",
          text: "User:\n#{user_prompt_text}\n\nRespond in JSON."
        }
      ]

      @image_urls.each do |url|
        content_parts << {
          type: "input_image",
          image_url: url
        }
      end

      payload = {
        model: model,
        instructions: instructions,
        input: [
          {
            role: "user",
            content: content_parts
          }
        ],
        text: { format: { type: "json_object" } },
        store: false
      }

      raw = openai_post_json!(
        api_key: api_key,
        url: "https://api.openai.com/v1/responses",
        payload: payload,
        timeout: timeout
      )

      output_text = extract_responses_output_text(raw).to_s.strip

      parsed =
        begin
          JSON.parse(output_text)
        rescue JSON::ParserError
          {}
        end

      risk_level = parsed["risk_level"].to_s
      risk_level = "medium" unless %w[low medium high].include?(risk_level)

      steps =
        if parsed["steps"].is_a?(Array)
          parsed["steps"].map(&:to_s).map(&:strip).reject(&:blank?)
        else
          []
        end

      summary = parsed["summary"].to_s.strip
      summary = "I can help, but I need a little more detail. What are you seeing on the screen?" if summary.blank?

      {
        risk_level: risk_level,
        title: parsed["title"].to_s,
        summary: summary,
        steps: steps,
        escalate_suggested: !!parsed["escalate_suggested"],
        confidence: parsed["confidence"].to_f.clamp(0.0, 1.0),
        show_contact_panel: false,
        escalation_reason: nil,
        model: model,
        prompt_version: "public_llm_v1"
      }
    end

    def openai_post_json!(api_key:, url:, payload:, timeout:)
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = timeout
      http.read_timeout = timeout

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"] = "application/json"
      req.body = payload.to_json

      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        raise "OpenAI error #{res.code}: #{res.body}"
      end

      JSON.parse(res.body)
    end

    def extract_responses_output_text(raw)
      out = raw["output"]
      return "" unless out.is_a?(Array)

      texts = []

      out.each do |item|
        next unless item.is_a?(Hash)
        next unless item["type"] == "message"

        content = item["content"]
        next unless content.is_a?(Array)

        content.each do |part|
          next unless part.is_a?(Hash)
          texts << part["text"].to_s if part["type"] == "output_text"
        end
      end

      texts.join("\n")
    end
  end
end