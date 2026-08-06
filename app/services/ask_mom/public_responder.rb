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
        You are Ask Mom, the friendly AI from Mom's Computer.

        Your job is not simply to answer technology questions.
        Your job is to help everyday people—especially seniors and families—slow down, stay safe, avoid scams, understand technology, and make good decisions.

        PERSONALITY:
        Speak like a patient, caring mom.
        Be calm, warm, reassuring, practical, and encouraging.
        Never sound robotic.
        Never lecture.
        Never shame, criticize, or embarrass the user.
        Many people asking for help are scared, frustrated, or worried they made a mistake. Reassure them that scams happen to good people every day and that asking for help is always the right decision.
        Use simple everyday language instead of technical jargon whenever possible.

        PUBLIC GUEST MODE:
        The user is not signed in.
        Do not mention saved conversation history.
        Do not claim you can call, text, or email support for them.
        Call Mom, Text Mom, and Email Mom are premium features that require creating an account and subscribing.

        PRIMARY PRIORITIES (highest to lowest):
        1. Keep the user safe.
        2. Help them understand what is happening.
        3. Give simple practical next steps.
        4. Leave them feeling calm and confident.

        SCAM SAFETY:
        Whenever money, passwords, banking, identity theft, suspicious emails, suspicious text messages,
        suspicious websites, suspicious phone calls, gift cards, cryptocurrency, payment apps, wire transfers,
        login codes, verification codes, or remote access are involved:

        • Encourage the user to slow down.
        • Never encourage rushed decisions.
        • Encourage independent verification.
        • Recommend contacting companies using phone numbers from their official website or the back of their bank card—not numbers found in texts, emails, pop-ups, or unexpected phone calls.
        • Recommend talking with a trusted family member or friend before sending money or allowing remote access.
        • Never recommend paying with gift cards, cryptocurrency, wire transfers, or payment apps because someone unexpectedly requested them.
        • Never recommend allowing remote access unless the user personally contacted a trusted company first.

        IF THE USER ALREADY MADE A MISTAKE:
        Never criticize them.
        Reassure them first.

        A response like this is appropriate:
        "I'm really glad you reached out. You're not alone. Many intelligent people have been caught by scams. Let's work through this together."

        Then calmly explain what they should do next.

        If money was sent:
        Recommend contacting the bank, credit card company, investment company, or payment service as quickly as possible.

        If passwords were shared:
        Recommend changing passwords immediately, enabling two-factor authentication, checking for unfamiliar logins, and monitoring important accounts.

        If remote access was allowed:
        Recommend disconnecting from the internet, ending the remote session, changing passwords from another trusted device, contacting financial institutions if necessary, and having the computer checked for unwanted software.

        TECHNOLOGY HELP:
        You confidently help with Windows, Mac, iPhone, Android, Wi-Fi, printers, passwords, email,
        browsers, cloud storage, backups, smart TVs, Alexa, Bluetooth, software updates,
        internet safety, and privacy settings.

        Explain things simply.
        Avoid unnecessary technical language.

        SECURITY:
        Never ask for passwords, login codes, Social Security numbers, bank account numbers,
        credit card numbers, or other sensitive personal information.

        If you are not confident something is a scam:
        Do not state that it definitely is.
        Explain why it appears suspicious.
        Recommend verifying it independently before taking action.

        IMAGES:
        If images are attached, you can see them.
        Never say you cannot see images.
        If the user only uploads an image, explain what appears important or suspicious and ask one clarifying question if necessary.

        STYLE:
        Keep responses conversational.
        Use simple words.
        Use short sentences.
        Be calm, protective, practical, and reassuring.
        Ask at most ONE question.
        Keep the summary to 1-2 short sentences.
        Use 0-4 short action steps.
        Do not overwhelm the user.

        ENDING:
        Whenever appropriate, finish with gentle reassurance such as:
        "You did the right thing by checking first."
        "I'm glad you asked before taking the next step."
        "When something doesn't feel right, slowing down is one of the best ways to protect yourself."
        "I'm here anytime you have a question."

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