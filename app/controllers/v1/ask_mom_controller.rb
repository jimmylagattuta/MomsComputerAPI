# app/controllers/v1/ask_mom_controller.rb
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

      # ✅ Pass context (enables greeting variation + future routing)
      ai = AiService.call(
        user: current_user,
        text: user_message.content,
        context: { conversation_id: conversation.id }
      )

      # ✅ Coerce/guarantee output (prevents blank bubbles)
      summary = ai[:summary].to_s.strip
      summary = "Alright—tell me what you’re seeing on the screen." if summary.empty?

      steps =
        case ai[:steps]
        when Array
          ai[:steps].map { |s| s.to_s.strip }.reject(&:empty?)
        else
          []
        end

      if steps.empty?
        steps = [
          "What device is it (iPhone/Android/Mac/Windows)?",
          "What app or website are you in?",
          "What does the screen say (exact words), and is anyone asking for money, codes, or remote access?"
        ]
      end

      risk_level = ai[:risk_level].to_s.presence || "medium"
      escalate_suggested = !!ai[:escalate_suggested]

      confidence = ai[:confidence].to_f
      confidence = [[confidence, 0.0].max, 1.0].min

      model = ai[:model].to_s.presence || "stub"
      prompt_version = ai[:prompt_version].to_s.presence || "v1"

      # ✅ Store formatted message content too (nice for history/debug)
      content_text =
        if steps.any?
          ([summary, "", *steps.each_with_index.map { |s, i| "#{i + 1}. #{s}" }]).join("\n")
        else
          summary
        end

      # Persist AI message with TOP-LEVEL metadata keys
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
          # Optional dev routing metadata (won't break older clients)
          "llm_recommended" => !!ai[:llm_recommended],
          "llm_reason" => ai[:llm_reason].to_s
        }
      )

      # Keep conversation status/risk updated (NO tickets)
      conversation.update!(
        risk_level: ai_message.risk_level,
        last_message_at: Time.current,
        status: escalate_suggested ? "escalated" : conversation.status
      )

      # ✅ Required structured payload (reliable keys)
      render json: {
        conversation_id: conversation.id,
        message_id: ai_message.id,
        risk_level: ai_message.risk_level,
        summary: ai_message.metadata["summary"],
        steps: ai_message.metadata["steps"],
        escalate_suggested: ai_message.metadata["escalate_suggested"],
        confidence: ai_message.metadata["confidence"],
        # Optional dev routing metadata (safe add)
        llm_recommended: ai_message.metadata["llm_recommended"],
        llm_reason: ai_message.metadata["llm_reason"]
      }, status: :ok
    end
  end
end