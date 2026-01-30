# app/controllers/v1/ask_mom_controller.rb
require "net/http"
require "json"
require "uri"

module V1
  class AskMomController < ApplicationController
    include JwtAuth
    include Rails.application.routes.url_helpers

    before_action :authenticate_user!

    def create
      # ✅ Multipart images support: images[] (Rails normalizes images[] -> params[:images])
      uploaded_images = params[:images]
      uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
      uploaded_images = uploaded_images.compact

      # ✅ Accept either payload shape:
      # - { "text": "Hi" }
      # - { "ask_mom": { "text": "Hi" } }
      #
      # IMPORTANT:
      # - Allow text to be blank if images exist.
      # - Only hard error if BOTH text blank AND no images.
      text = extract_text_param(params)

      Rails.logger.info("[AskMomController] create: text_len=#{text.to_s.length} images=#{uploaded_images.length} content_type_hint=#{request.content_type}")

      if text.blank? && uploaded_images.empty?
        render json: {
          error: "invalid_request",
          message: "Please type a message or attach an image.",
          conversation_id: params[:conversation_id]
        }, status: :bad_request
        return
      end

      content_type =
        if uploaded_images.any? && text.present?
          "mixed"
        elsif uploaded_images.any?
          "image"
        else
          "text"
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
      if text.present? && SensitiveDataRedactor.contains_sensitive?(text)
        redacted = SensitiveDataRedactor.redact(text)
        reasons = SensitiveDataRedactor.reasons(text)

        user_message = conversation.messages.create!(
          sender_type: "user",
          sender_id: current_user.id,
          content: redacted,
          content_type: content_type,
          risk_level: "unknown",
          metadata: { redacted: true, redaction_reasons: reasons }
        )

        user_message.create_blocked_artifact!(
          reason: reasons.join(","),
          redacted_content: redacted,
          metadata: { note: "Original content intentionally not stored." }
        )
      else
        # ✅ If image-only, store empty string (NOT nil) so downstream code stays simple.
        user_message = conversation.messages.create!(
          sender_type: "user",
          sender_id: current_user.id,
          content: text.to_s,
          content_type: content_type,
          risk_level: "unknown",
          metadata: {}
        )
      end

      # ✅ Attach images AFTER creating the message
      if uploaded_images.any?
        uploaded_images.each { |img| user_message.images.attach(img) }
      end

      Rails.logger.info(
        "[AskMomController] stored user_message id=#{user_message.id} content_type=#{user_message.content_type} images_attached=#{user_message.images.attached? ? user_message.images.size : 0}"
      )

      # ✅ Anti-avalanche throttle (transport-level only)
      recent_user_msgs =
        conversation.messages
                    .where(sender_type: "user")
                    .where("created_at > ?", 10.seconds.ago)
                    .count

      if recent_user_msgs > 3
        render json: {
          error: "rate_limited",
          message: "Too many messages too quickly. Please wait a moment and try again.",
          conversation_id: conversation.id,
          user_message_id: user_message.id,
          user_images: image_urls_for(user_message)
        }, status: :too_many_requests
        return
      end

      # ============================================================
      # ✅ Guardrails (pre-LLM) + deterministic contact drafts
      # ============================================================
      pre_risk_level = compute_risk_level_pre_llm(user_message.content)

      guard = AskMom::Guardrails.new(
        conversation: conversation,
        new_user_text: user_message.content,
        risk_level: pre_risk_level
      ).check

      # ✅ Hard-block only (too long / rate / llm budget)
      if guard[:block]
        assistant_text = [
          guard[:friendly_message].to_s.strip.presence || "I can’t safely keep going with that right now.",
          "",
          "Let’s contact a person instead of continuing here.",
          "Tap Text, Email, or Call below and I’ll open your phone with a pre-filled message."
        ].compact.join("\n")

        ai_message = conversation.messages.create!(
          sender_type: "ai",
          sender_id: nil,
          content: assistant_text,
          content_type: "text",
          risk_level: pre_risk_level,
          ai_model: "guardrails",
          ai_prompt_version: "guardrails_v1",
          ai_confidence: 0.0,
          metadata: {
            "summary" => assistant_text,
            "steps" => [],
            "escalate_suggested" => true,
            "confidence" => 0.0,
            "title" => sanitize_title(conversation.summary.to_s)
          }
        )

        conversation.update!(
          risk_level: ai_message.risk_level,
          last_message_at: Time.current,
          status: "escalated"
        )

        draft = AskMom::ContactDraftBuilder.new(
          conversation: conversation,
          user_text: user_message.content, # ✅ first-message-only
          risk_level: pre_risk_level
        ).build

        render json: {
          conversation_id: conversation.id,
          message_id: ai_message.id,
          risk_level: ai_message.risk_level,
          summary: ai_message.metadata["summary"],
          steps: ai_message.metadata["steps"],
          escalate_suggested: ai_message.metadata["escalate_suggested"],
          confidence: ai_message.metadata["confidence"],
          conversation_title: conversation.summary,

          show_contact_panel: true,
          escalation_reason: guard[:reason],
          contact_actions: { sms: true, email: true, call: true },
          contact_draft: draft,
          contact_targets: nil,

          user_message_id: user_message.id,
          user_images: image_urls_for(user_message)
        }, status: :ok
        return
      end

      # ============================================================
      # ✅ SOFT ESCALATION (stuck 3x rule)
      # ============================================================
      if guard[:show_contact_panel]
        assistant_text = [
          "Okay — we’re going in circles.",
          "",
          "Let’s contact a person instead of continuing here.",
          "Tap Text, Email, or Call below and I’ll open your phone with a pre-filled message."
        ].join("\n")

        ai_message = conversation.messages.create!(
          sender_type: "ai",
          sender_id: nil,
          content: assistant_text,
          content_type: "text",
          risk_level: pre_risk_level,
          ai_model: "guardrails",
          ai_prompt_version: "guardrails_v1",
          ai_confidence: 0.0,
          metadata: {
            "summary" => assistant_text,
            "steps" => [],
            "escalate_suggested" => true,
            "confidence" => 0.0,
            "title" => sanitize_title(conversation.summary.to_s)
          }
        )

        conversation.update!(
          risk_level: ai_message.risk_level,
          last_message_at: Time.current,
          status: "escalated"
        )

        draft = AskMom::ContactDraftBuilder.new(
          conversation: conversation,
          user_text: user_message.content, # ✅ first-message-only
          risk_level: pre_risk_level
        ).build

        render json: {
          conversation_id: conversation.id,
          message_id: ai_message.id,
          risk_level: ai_message.risk_level,
          summary: ai_message.metadata["summary"],
          steps: ai_message.metadata["steps"],
          escalate_suggested: ai_message.metadata["escalate_suggested"],
          confidence: ai_message.metadata["confidence"],
          conversation_title: conversation.summary,

          show_contact_panel: true,
          escalation_reason: guard[:reason] || "stuck",
          contact_actions: { sms: true, email: true, call: true },
          contact_draft: draft,
          contact_targets: nil,

          user_message_id: user_message.id,
          user_images: image_urls_for(user_message)
        }, status: :ok
        return
      end

      # ✅ LLM call (WITH images via image_url)
      ai = ask_mom_llm(
        user_text: user_message.content,
        user: current_user,
        conversation: conversation,
        user_message: user_message
      )

      summary = ai[:summary].to_s.strip
      steps = ai[:steps].is_a?(Array) ? ai[:steps].map { |s| s.to_s.strip }.reject(&:empty?) : []

      risk_level = ai[:risk_level].to_s.strip
      risk_level = "medium" unless %w[low medium high].include?(risk_level)

      escalate_suggested = !!ai[:escalate_suggested]

      confidence = ai[:confidence].to_f
      confidence = [[confidence, 0.0].max, 1.0].min

      model = ai[:model].to_s.presence || "unknown"
      prompt_version = ai[:prompt_version].to_s.presence || "llm_v1"

      title = sanitize_title(ai[:title].to_s.strip)

      if summary.empty?
        render json: {
          error: "llm_invalid_response",
          message: "Assistant response unavailable. Please try again.",
          conversation_id: conversation.id,
          user_message_id: user_message.id,
          user_images: image_urls_for(user_message)
        }, status: :bad_gateway
        return
      end

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
          "confidence" => confidence,
          "title" => title
        }
      )

      update_hash = {
        risk_level: ai_message.risk_level,
        last_message_at: Time.current,
        status: escalate_suggested ? "escalated" : conversation.status
      }
      update_hash[:summary] = title if title.present?
      conversation.update!(update_hash)

      render json: {
        conversation_id: conversation.id,
        message_id: ai_message.id,
        risk_level: ai_message.risk_level,
        summary: ai_message.metadata["summary"],
        steps: ai_message.metadata["steps"],
        escalate_suggested: ai_message.metadata["escalate_suggested"],
        confidence: ai_message.metadata["confidence"],
        conversation_title: conversation.summary,

        show_contact_panel: false,
        escalation_reason: nil,
        contact_actions: nil,
        contact_draft: nil,
        contact_targets: nil,

        user_message_id: user_message.id,
        user_images: image_urls_for(user_message)
      }, status: :ok
    end

    private

    # ----------------------------
    # Params
    # ----------------------------
    def extract_text_param(p)
      # If top-level "text" key exists (even blank), honor it.
      if p.key?(:text) || p.key?("text")
        return p[:text].to_s
      end

      # Otherwise try nested ask_mom[text], but don't blow up if missing.
      begin
        p.require(:ask_mom).permit(:text).fetch(:text).to_s
      rescue ActionController::ParameterMissing
        ""
      end
    end

    # ----------------------------
    # URL host helper
    # ----------------------------
    def url_host
      # Prefer explicit host if set (recommended for production),
      # else fall back to request.base_url for local/dev.
      ENV["APP_HOST"].to_s.presence || request.base_url
    end

    # ----------------------------
    # Images (for app UI + for LLM)
    # ----------------------------
    def image_urls_for(message)
      return [] unless message&.images&.attached?

      message.images.map do |att|
        # S3 presigned URL (publicly reachable by OpenAI)
        att.blob.url(
          expires_in: 10.minutes,
          disposition: "inline",
          filename: att.blob.filename
        )
      end
    rescue => e
      Rails.logger.warn("[AskMomController] image_urls_for failed: #{e.class}: #{e.message}")
      []
    end


    # ----------------------------
    # Risk + Title
    # ----------------------------
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

    def sanitize_title(s)
      t = s.to_s.strip
      return "" if t.empty?

      t = t.gsub(/\s+/, " ")
      t = t.gsub(/[\r\n\t]/, " ").strip
      t = t.gsub(/\A["'“”‘’]+/, "").gsub(/["'“”‘’]+\z/, "")
      t = t[0, 48] if t.length > 48
      t
    end

    # ----------------------------
    # Context
    # ----------------------------
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
        content = content[0, 900] if content.length > 900
        lines << "#{role}: #{content}"
      end

      text = lines.join("\n")
      text = text[-max_chars, max_chars] if text.length > max_chars
      text
    end

    # ----------------------------
    # LLM (WITH IMAGES via image_url)
    # ----------------------------
    def ask_mom_llm(user_text:, user:, conversation:, user_message:)
      api_key = ENV["OPENAI_API_KEY"].to_s
      raise "Missing OPENAI_API_KEY" if api_key.empty?

      model = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
      timeout = ENV.fetch("OPENAI_TIMEOUT", "20").to_i

      instructions = <<~TXT
        You are "Mom's Computer" — a charmingly curmudgeonly, no-nonsense scam-safety + tech-help assistant for SENIORS.
        Dry and blunt, lightly sarcastic, but NEVER cruel. If the user sounds scared or confused, drop the snark.
        Use simple words, short sentences, and very concrete actions (tap this, open that). Avoid jargon.

        IMPORTANT ABOUT IMAGES:
        - If images are attached, you CAN see them.
        - Do NOT say you "can't see images" or "only descriptions help."
        - If the user sends only an image with no text, describe what you see and ask ONE clarifying question.

        CONVERSATION STYLE:
        - You MAY include at most ONE short curmudgeonly quip per response (max 8 words).
        - NEVER use sarcasm if the user seems scared, panicked, or confused.
        - Ask ONLY ONE question per response.
        - Keep summary 1–2 sentences.

        Output must be valid JSON only. No markdown. No extra text.

        Return exactly these keys:
        - risk_level: "low" | "medium" | "high"
        - title: a short, intuitive conversation title (3–7 words). No punctuation at the end.
        - summary: 1-2 sentences (ALWAYS present). Include the ONE question here if you need info.
        - steps: array of 0-4 short action strings
        - escalate_suggested: boolean
        - confidence: number 0..1

        SAFETY RULES:
        - PRIVACY: Never ask for passwords, login codes, SSN, or bank/credit card numbers.
        - If money/codes/gift cards/crypto/remote access is involved => risk_level MUST be "high".
      TXT

      ctx = conversation_context_text(conversation, turns: 10, max_chars: 4500)

      user_prompt_text =
        if user_text.to_s.strip.empty?
          "The user sent only image(s). Analyze the image(s). Tell me what looks important or suspicious, and what I should do next."
        else
          user_text.to_s
        end

      # ✅ Generate signed image URLs and pass them as input_image.image_url
      image_urls = image_urls_for(user_message)

      Rails.logger.info("[AskMomController] LLM: model=#{model} ctx_chars=#{ctx.length} sending_images=#{image_urls.length}")
      image_urls.each_with_index do |u, i|
        Rails.logger.info("[AskMomController] LLM image_url[#{i}]=#{u[0, 140]}...")
      end

      content_parts = []
      content_parts << {
        type: "input_text",
        text: "Conversation so far:\n#{ctx}\n\nUser:\n#{user_prompt_text}\n\nRespond in JSON."
      }

      image_urls.each do |u|
        content_parts << { type: "input_image", image_url: u }
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

      {
        risk_level: parsed["risk_level"].to_s,
        title: parsed["title"].to_s,
        summary: parsed["summary"].to_s,
        steps: parsed["steps"].is_a?(Array) ? parsed["steps"] : [],
        escalate_suggested: !!parsed["escalate_suggested"],
        confidence: parsed["confidence"].to_f,
        model: model,
        prompt_version: "llm_v1"
      }
    end

    # ----------------------------
    # OpenAI HTTP helpers
    # ----------------------------
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
