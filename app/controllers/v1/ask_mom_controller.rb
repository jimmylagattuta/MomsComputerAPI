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
      uploaded_images = params[:images]
      uploaded_images = [uploaded_images].compact unless uploaded_images.is_a?(Array)
      uploaded_images = uploaded_images.compact

      text = extract_text_param(params)

      Rails.logger.info(
        "[AskMomController] create: user_id=#{current_user.id} text_len=#{text.to_s.length} images=#{uploaded_images.length} content_type_hint=#{request.content_type}"
      )

      if text.blank? && uploaded_images.empty?
        render json: {
          error: "invalid_request",
          message: "Please type a message or attach an image.",
          conversation_id: params[:conversation_id]
        }, status: :bad_request
        return
      end

      tier = AskMom::Limits.tier_for_user(current_user)
      limits = AskMom::Limits.for_user(current_user)

      image_validation = validate_uploaded_images(uploaded_images, limits)
      unless image_validation[:ok]
        render json: {
          error: image_validation[:error],
          message: image_validation[:message],
          limits: nil
        }, status: image_validation[:status]
        return
      end

      conversation_id = params[:conversation_id]
      new_conversation = conversation_id.blank?

      # ============================================================
      # ✅ LIMIT CHECK BEFORE CREATING USER MESSAGE
      # ============================================================
      #
      # For a new conversation, check using a temporary conversation key first.
      # This prevents creating a Conversation if the user already hit daily limits.
      #
      preliminary_limiter = nil
      preliminary_check = nil

      if new_conversation
        preliminary_limiter = AskMom::UsageLimiter.new(
          actor_key: signed_in_actor_key,
          tier: tier,
          limits: limits,
          conversation_key: "#{signed_in_actor_key}:conversation:new"
        )

        preliminary_check = preliminary_limiter.check!(
          text: text,
          image_count: uploaded_images.length,
          new_conversation: true
        )

        unless preliminary_check.allowed
          render_limit_error(preliminary_check)
          return
        end

        conversation = current_user.conversations.create!(
          channel: "ask_mom",
          status: "open",
          risk_level: "unknown",
          last_message_at: Time.current
        )
      else
        conversation = current_user.conversations.find(conversation_id)
      end

      limiter = AskMom::UsageLimiter.new(
        actor_key: signed_in_actor_key,
        tier: tier,
        limits: limits,
        conversation_key: signed_in_conversation_key(conversation)
      )

      unless new_conversation
        check = limiter.check!(
          text: text,
          image_count: uploaded_images.length,
          new_conversation: false
        )

        unless check.allowed
          render_limit_error(check, conversation_id: conversation.id)
          return
        end
      end

      content_type =
        if uploaded_images.any? && text.present?
          "mixed"
        elsif uploaded_images.any?
          "image"
        else
          "text"
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
          metadata: {
            redacted: true,
            redaction_reasons: reasons,
            access_tier: tier.to_s
          }
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
          content: text.to_s,
          content_type: content_type,
          risk_level: "unknown",
          metadata: {
            access_tier: tier.to_s
          }
        )
      end

      if uploaded_images.any?
        uploaded_images.each { |img| user_message.images.attach(img) }
      end

      Rails.logger.info(
        "[AskMomController] stored user_message id=#{user_message.id} content_type=#{user_message.content_type} images_attached=#{user_message.images.attached? ? user_message.images.size : 0} tier=#{tier}"
      )

      # ============================================================
      # ✅ Guardrails (pre-LLM) + deterministic contact drafts
      # ============================================================
      pre_risk_level = compute_risk_level_pre_llm(user_message.content)

      guard = AskMom::Guardrails.new(
        conversation: conversation,
        new_user_text: user_message.content,
        risk_level: pre_risk_level,
        settings: guardrail_settings_for(limits)
      ).check

      # ✅ Hard-block only (too long / rate / llm budget)
      if guard[:block]
        assistant_text = [
          guard[:friendly_message].to_s.strip.presence || "I can’t safely keep going with that right now.",
          "",
          support_unlocked?(limits) ? "Let’s contact a person instead of continuing here." : "A real person would be better here, but Call/Text/Email Mom requires a subscription.",
          support_unlocked?(limits) ? "Tap Text, Email, or Call below and I’ll open your phone with a pre-filled message." : "Subscribe to unlock Text Mom, Email Mom, and Call Mom."
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
            "title" => sanitize_title(conversation.summary.to_s),
            "access_tier" => tier.to_s
          }
        )

        conversation.update!(
          risk_level: ai_message.risk_level,
          last_message_at: Time.current,
          status: "escalated"
        )

        draft = AskMom::ContactDraftBuilder.new(
          conversation: conversation,
          user_text: user_message.content,
          risk_level: pre_risk_level
        ).build

        updated_limits = limiter.increment!(
          image_count: uploaded_images.length,
          new_conversation: new_conversation
        )

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
          contact_actions: contact_actions_for(limits),
          locked_contact_actions: locked_contact_actions_for(limits),
          contact_draft: support_unlocked?(limits) ? draft : nil,
          contact_targets: nil,

          user_message_id: user_message.id,
          user_images: image_urls_for(user_message),
          limits: updated_limits
        }, status: :ok
        return
      end

      # ============================================================
      # ✅ SOFT ESCALATION (stuck 3x rule)
      # ============================================================
      if guard[:show_contact_panel]
        assistant_text =
          if support_unlocked?(limits)
            [
              "Okay — we’re going in circles.",
              "",
              "Let’s contact a person instead of continuing here.",
              "Tap Text, Email, or Call below and I’ll open your phone with a pre-filled message."
            ].join("\n")
          else
            [
              "Okay — we’re going in circles.",
              "",
              "A real person would be better here, but Call/Text/Email Mom requires a subscription.",
              "Subscribe to unlock Text Mom, Email Mom, and Call Mom."
            ].join("\n")
          end

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
            "title" => sanitize_title(conversation.summary.to_s),
            "access_tier" => tier.to_s
          }
        )

        conversation.update!(
          risk_level: ai_message.risk_level,
          last_message_at: Time.current,
          status: "escalated"
        )

        draft = AskMom::ContactDraftBuilder.new(
          conversation: conversation,
          user_text: user_message.content,
          risk_level: pre_risk_level
        ).build

        updated_limits = limiter.increment!(
          image_count: uploaded_images.length,
          new_conversation: new_conversation
        )

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
          contact_actions: contact_actions_for(limits),
          locked_contact_actions: locked_contact_actions_for(limits),
          contact_draft: support_unlocked?(limits) ? draft : nil,
          contact_targets: nil,

          user_message_id: user_message.id,
          user_images: image_urls_for(user_message),
          limits: updated_limits
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
          user_images: image_urls_for(user_message),
          limits: limiter.usage_payload
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
          "title" => title,
          "access_tier" => tier.to_s
        }
      )

      update_hash = {
        risk_level: ai_message.risk_level,
        last_message_at: Time.current,
        status: escalate_suggested ? "escalated" : conversation.status
      }
      update_hash[:summary] = title if title.present?
      conversation.update!(update_hash)

      updated_limits = limiter.increment!(
        image_count: uploaded_images.length,
        new_conversation: new_conversation
      )

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
        locked_contact_actions: locked_contact_actions_for(limits),
        contact_draft: nil,
        contact_targets: nil,

        user_message_id: user_message.id,
        user_images: image_urls_for(user_message),
        limits: updated_limits
      }, status: :ok
    end

    private

    # ----------------------------
    # Tier / limits
    # ----------------------------
    def signed_in_actor_key
      "user:#{current_user.id}"
    end

    def signed_in_conversation_key(conversation)
      "user:#{current_user.id}:conversation:#{conversation.id}"
    end

    def support_unlocked?(limits)
      limits[:support_unlocked] == true
    end

    def contact_actions_for(limits)
      unlocked = support_unlocked?(limits)

      {
        sms: unlocked,
        email: unlocked,
        call: unlocked
      }
    end

    def locked_contact_actions_for(limits)
      unlocked = support_unlocked?(limits)

      {
        sms: !unlocked,
        email: !unlocked,
        call: !unlocked
      }
    end

    def guardrail_settings_for(limits)
      {
        max_text_chars: limits[:chars_per_message].to_i,
        max_user_per_60s: [limits[:burst_messages].to_i * 6, 1].max,
        max_llm_calls: limits[:messages_per_conversation].to_i,
        max_llm_calls_high: limits[:messages_per_conversation].to_i,
        stuck_within_last_user_turns: 10,
        stuck_min_hits: 3,
        repeat_within_last_user_turns: 3,
        repeat_min_matches: 2,
        show_panel_on_llm_budget: true
      }
    end

    def render_limit_error(result, conversation_id: nil)
      render json: {
        error: result.error,
        message: result.message,
        conversation_id: conversation_id,
        limits: result.limits
      }, status: result.status
    end

    # ----------------------------
    # Image validation
    # ----------------------------
    def validate_uploaded_images(images, limits)
      max_images = limits[:images_per_message].to_i
      return { ok: true } if images.blank?

      if images.length > max_images
        return {
          ok: false,
          error: "too_many_images",
          message: "You can attach up to #{max_images} image(s) per message.",
          status: :unprocessable_entity
        }
      end

      max_bytes =
        if limits[:support_unlocked]
          10.megabytes
        else
          6.megabytes
        end

      allowed_types = %w[
        image/jpeg
        image/jpg
        image/png
        image/webp
        image/heic
        image/heif
      ]

      images.each do |img|
        content_type = img.respond_to?(:content_type) ? img.content_type.to_s.downcase : ""
        size = img.respond_to?(:size) ? img.size.to_i : 0

        unless allowed_types.include?(content_type)
          return {
            ok: false,
            error: "invalid_image_type",
            message: "Please upload a JPG, PNG, WEBP, HEIC, or HEIF image.",
            status: :unprocessable_entity
          }
        end

        if size <= 0 || size > max_bytes
          return {
            ok: false,
            error: "image_too_large",
            message: "That image is too large. Please upload a smaller screenshot or photo.",
            status: :payload_too_large
          }
        end
      end

      { ok: true }
    end

    # ----------------------------
    # Params
    # ----------------------------
    def extract_text_param(p)
      if p.key?(:text) || p.key?("text")
        return p[:text].to_s
      end

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
      ENV["APP_HOST"].to_s.presence || request.base_url
    end

    # ----------------------------
    # Images (for app UI + for LLM)
    # ----------------------------
    def image_urls_for(message)
      return [] unless message&.images&.attached?

      message.images.map do |att|
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

      ctx = conversation_context_text(conversation, turns: 10, max_chars: 4500)

      user_prompt_text =
        if user_text.to_s.strip.empty?
          "The user sent only image(s). Analyze the image(s). Tell me what looks important or suspicious, and what I should do next."
        else
          user_text.to_s
        end

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