# app/controllers/v1/ask_mom_controller.rb
require "net/http"
require "json"
require "uri"

module V1
  class AskMomController < ApplicationController
    include JwtAuth

    before_action :authenticate_user!

    def create
      # ✅ Accept either payload shape:
      # - { "text": "Hi" }
      # - { "ask_mom": { "text": "Hi" } }
      text =
        if params[:text].present?
          params[:text].to_s
        else
          params.require(:ask_mom).permit(:text).fetch(:text).to_s
        end

      conversation_id = params[:conversation_id]

      conversation =
        if conversation_id.present?
          current_user.conversations.find(conversation_id)
        else
          current_user.conversations.create!(
            channel: "ask_mom",
            status: "open",
            risk_level: "unknown",
            last_message_at: Time.current
          )
        end

      # Store user message (redacted if needed)
      if SensitiveDataRedactor.contains_sensitive?(text)
        redacted = SensitiveDataRedactor.redact(text)
        reasons = SensitiveDataRedactor.reasons(text)

        user_message = conversation.messages.create!(
          sender_type: "user",
          sender_id: current_user.id,
          content: redacted,
          content_type: "text",
          risk_level: "unknown",
          metadata: { redacted: true, redaction_reasons: reasons }
        )

        user_message.create_blocked_artifact!(
          reason: reasons.join(","),
          redacted_content: redacted,
          metadata: { note: "Original content intentionally not stored." }
        )
      else
        user_message = conversation.messages.create!(
          sender_type: "user",
          sender_id: current_user.id,
          content: text,
          content_type: "text",
          risk_level: "unknown",
          metadata: {}
        )
      end

      # ✅ Anti-avalanche throttle (transport-level guardrail only)
      recent_user_msgs =
        conversation.messages
                    .where(sender_type: "user")
                    .where("created_at > ?", 10.seconds.ago)
                    .count

      if recent_user_msgs > 3
        render json: {
          error: "rate_limited",
          message: "Too many messages too quickly. Please wait a moment and try again."
        }, status: :too_many_requests
        return
      end

      # ✅ Direct LLM call (LLM owns the assistant voice)
      ai = ask_mom_llm(
        user_text: user_message.content,
        user: current_user,
        conversation: conversation
      )

      # ✅ Normalize types (not “talking”, just shaping data)
      summary = ai[:summary].to_s.strip
      steps = ai[:steps].is_a?(Array) ? ai[:steps].map { |s| s.to_s.strip }.reject(&:empty?) : []

      risk_level = ai[:risk_level].to_s.strip
      risk_level = "medium" unless %w[low medium high].include?(risk_level)

      escalate_suggested = !!ai[:escalate_suggested]

      confidence = ai[:confidence].to_f
      confidence = [[confidence, 0.0].max, 1.0].min

      model = ai[:model].to_s.presence || "unknown"
      prompt_version = ai[:prompt_version].to_s.presence || "llm_v1"

      # ✅ If the LLM fails to provide required fields, treat as upstream failure.
      # (No Rails-authored assistant message.)
      if summary.empty?
        render json: {
          error: "llm_invalid_response",
          message: "Assistant response unavailable. Please try again."
        }, status: :bad_gateway
        return
      end

      # Store formatted message content (for history/debug)
      content_text =
        if steps.any?
          ([summary, "", *steps.each_with_index.map { |s, i| "#{i + 1}. #{s}" }]).join("\n")
        else
          summary
        end

      ai_message = conversation.messages.create!(
        sender_type: "ai",
        sender_id: nil,
        content: content_text,
        content_type: "text",
        risk_level: risk_level,
        ai_model: model,
        ai_prompt_version: prompt_version,
        ai_confidence: confidence,
        metadata: {
          "summary" => summary,
          "steps" => steps,
          "escalate_suggested" => escalate_suggested,
          "confidence" => confidence
        }
      )

      conversation.update!(
        risk_level: ai_message.risk_level,
        last_message_at: Time.current,
        status: escalate_suggested ? "escalated" : conversation.status
      )

      render json: {
        conversation_id: conversation.id,
        message_id: ai_message.id,
        risk_level: ai_message.risk_level,
        summary: ai_message.metadata["summary"],
        steps: ai_message.metadata["steps"],
        escalate_suggested: ai_message.metadata["escalate_suggested"],
        confidence: ai_message.metadata["confidence"]
      }, status: :ok
    end

    private

    # Builds a compact transcript of the last N messages for the LLM.
    # Keeps cost bounded + avoids token avalanches.
    def conversation_context_text(conversation, turns: 8, max_chars: 4000)
      msgs =
        conversation.messages
                    .order(created_at: :desc)
                    .limit(turns)
                    .to_a
                    .reverse

      lines = []

      msgs.each do |m|
        role =
          case m.sender_type.to_s
          when "user" then "User"
          when "ai" then "Assistant"
          else "Other"
          end

        content = m.content.to_s.strip
        next if content.empty?

        # Keep each message sane
        content = content[0, 900] if content.length > 900

        lines << "#{role}: #{content}"
      end

      text = lines.join("\n")

      # Hard cap total context size
      if text.length > max_chars
        text = text[-max_chars, max_chars] # keep the most recent tail
      end

      text
    end

    def ask_mom_llm(user_text:, user:, conversation:)
      api_key = ENV["OPENAI_API_KEY"].to_s
      raise "Missing OPENAI_API_KEY" if api_key.empty?

      model = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
      timeout = ENV.fetch("OPENAI_TIMEOUT", "12").to_i

      instructions = <<~TXT
        You are "Mom's Computer" — a charmingly curmudgeonly, no-nonsense scam-safety + tech-help assistant for SENIORS.
        Dry and blunt, lightly sarcastic, but NEVER cruel. If the user sounds scared or confused, drop the snark.
        Use simple words, short sentences, and very concrete actions (tap this, open that). Avoid jargon.

        CONVERSATION STYLE (important):
        - Your vibe: dry, blunt, lightly sarcastic like a grumpy-but-caring relative.
        - You MAY include at most ONE short curmudgeonly quip per response (max 8 words).
          Examples: “Alright. Let’s fix this.” / “Yep. That’s suspicious.” / “Nope. Don’t click that.”
        - NEVER use sarcasm if the user seems scared, panicked, or confused. In that case: warm + calm only.
        - Always acknowledge what they did right (“Good. You did the right thing.”).
        - Always include a reassuring line that reduces panic (“You’re okay. We’ll handle this.”).
        - Ask for information like a real conversation: ask ONLY ONE question per response.
        - Steps are for actions. Put the ONE question in the summary (not in steps) when possible.
        - Keep summary 1–2 sentences, but it can be punchy. Prefer short, confident sentences.

        TONE DIAL:
        - If risk_level is "high": drop sarcasm, be calm and direct.
        - If risk_level is "medium": allow ONE quip.
        - If risk_level is "low": allow ONE quip.

        Output must be valid JSON only. No markdown. No extra text.

        Return exactly these keys:
        - risk_level: "low" | "medium" | "high"
        - summary: 1-2 sentences (ALWAYS present). Include the ONE question here if you need info.
        - steps: array of 0-4 short action strings (“Open Settings…”, “Turn on Airplane mode…”)
        - escalate_suggested: boolean
        - confidence: number 0..1

        SAFETY RULES:
        - If money, codes, gift cards, crypto, "refund", bank transfer, or remote access is involved => risk_level MUST be "high".
        - If user already paid/clicked/shared codes/installed remote access => escalate_suggested MUST be true.
        - If it’s a scam scenario, include “do this to be safe” actions (close tab, disconnect call, check bank app from official app, etc.).
        - If it’s troubleshooting, first identify device + what they see, then give the smallest next step.

        GREETINGS:
        - If the user only says “hi/hello”, respond briefly and ask what device they’re on (ONE question).
      TXT



      # Include last few turns (this is the “memory”)
      ctx = conversation_context_text(conversation, turns: 10, max_chars: 4500)

      # IMPORTANT: OpenAI requires the word "json" to appear in the input when using json_object mode.
      input_text = <<~INP
        Respond in JSON.

        Conversation so far:
        #{ctx}
      INP

      payload = {
        model: model,
        instructions: instructions,
        input: input_text,
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

      {
        risk_level: parsed["risk_level"].to_s,
        summary: parsed["summary"].to_s,
        steps: parsed["steps"].is_a?(Array) ? parsed["steps"] : [],
        escalate_suggested: !!parsed["escalate_suggested"],
        confidence: parsed["confidence"].to_f,
        model: model,
        prompt_version: "llm_v1"
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
