# app/services/ask_mom/contact_draft_builder.rb
# frozen_string_literal: true

module AskMom
  class ContactDraftBuilder
    def initialize(conversation:, user_text:, risk_level:, app_name: "Mom’s Computer")
      @conversation = conversation
      @user_text = user_text.to_s.strip
      @risk_level = (risk_level || "low").to_s
      @app_name = app_name
    end

    def build
      title = safe_title

      subject =
        if @risk_level == "high"
          "Possible scam — need quick advice"
        elsif title.present?
          "Tech help — stuck on #{title}"
        else
          "Tech help — quick question"
        end

      closing_question = closing_line_for(@risk_level)

      sms_body = [
        "Hey — can you help me real quick?",
        (title.present? ? "Topic: #{title}" : nil),
        (@user_text.present? ? "What happened: #{@user_text}" : nil),
        closing_question
      ].compact.join("\n")

      email_body = [
        "Hi,",
        "",
        "I’m using #{@app_name} and I’m not sure what to do next.",
        (title.present? ? "Topic: #{title}" : nil),
        "",
        (@user_text.present? ? "What happened:\n#{@user_text}" : nil),
        "",
        closing_question,
        "",
        "— Sent from #{@app_name}"
      ].compact.join("\n")

      {
        sms_body: sms_body,
        email_subject: subject,
        email_body: email_body
      }
    end

    private

    def closing_line_for(risk_level)
      case risk_level.to_s
      when "high"
        "What should I do right now to stay safe?"
      when "medium"
        "What should I do next?"
      else
        # low / normal tech help
        "What’s the next step I should try?"
      end
    end

    def safe_title
      t = nil
      t = @conversation.title if @conversation.respond_to?(:title)
      t = @conversation.summary if t.blank? && @conversation.respond_to?(:summary)
      String(t || "").strip.presence
    end
  end
end
