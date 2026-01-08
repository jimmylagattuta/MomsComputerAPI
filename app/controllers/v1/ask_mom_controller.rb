# app/controllers/v1/ask_mom_controller.rb
module V1
  class AskMomController < ApplicationController
    include JwtAuth

    def create
      text = params.require(:text).to_s
      conversation_id = params[:conversation_id]

      # Create or reuse conversation
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

      # Guardrail: redact if sensitive data appears
      if SensitiveDataRedactor.contains_sensitive?(text)
        redacted = SensitiveDataRedactor.redact(text)
        reasons = SensitiveDataRedactor.reasons(text)

        user_message = conversation.messages.create!(
          sender_type: "user",
          sender_id: current_user.id,
          content: redacted, # store only redacted
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

      # Call AI (use stored content, which may be redacted)
      ai_result = AiService.call(user: current_user, text: user_message.content, context: nil)

      # Persist AI message
      ai_message = conversation.messages.create!(
        sender_type: "ai",
        sender_id: nil,
        content: build_ai_message_text(ai_result),
        content_type: "text",
        risk_level: ai_result[:risk_level],
        ai_model: "stub",
        ai_prompt_version: "v1",
        ai_confidence: ai_result[:confidence],
        metadata: { structured: ai_result.except(:confidence) }
      )

      # Update conversation risk + timestamps
      conversation.update!(
        risk_level: ai_result[:risk_level],
        last_message_at: Time.current,
        status: ai_result[:escalate_suggested] ? "escalated" : conversation.status
      )

      # Auto-create escalation ticket on high risk (optional but recommended)
      ticket = nil
      if ai_result[:escalate_suggested]
        ticket = EscalationTicket.create!(
          user: current_user,
          conversation: conversation,
          status: "open",
          priority: "high",
          reason: "high_risk_scam",
          summary: ai_result[:summary]
        )
      end

      render json: {
        conversation_id: conversation.id,
        user_message_id: user_message.id,
        ai_message_id: ai_message.id,
        risk_level: ai_result[:risk_level],
        summary: ai_result[:summary],
        steps: ai_result[:steps],
        escalate_suggested: ai_result[:escalate_suggested],
        escalation_ticket_id: ticket&.id
      }, status: :ok
    end

    private

    def build_ai_message_text(result)
      lines = []
      lines << result[:summary].to_s
      lines << ""
      result[:steps].to_a.each_with_index do |s, i|
        lines << "#{i + 1}. #{s}"
      end
      lines.join("\n")
    end
  end
end