# app/controllers/v1/conversations_controller.rb
module V1
  class ConversationsController < ApplicationController
    include JwtAuth
    before_action :authenticate_user!

    def index
      limit = (params[:limit].presence || 20).to_i
      limit = 50 if limit > 50

      q = params[:q].to_s.strip
      scope = current_user.conversations

      if q.present?
        pattern = "%#{sanitize_sql_like(q)}%"

        # ✅ SQLite doesn't support ILIKE
        # ✅ Postgres does, but LOWER(...) LIKE works everywhere
        scope =
          scope.joins(:messages)
               .where("LOWER(messages.content) LIKE LOWER(?)", pattern)
               .distinct
      end

      conversations =
        scope.order(last_message_at: :desc)
             .limit(limit)

      render json: conversations.map { |c|
        {
          id: c.id,
          title: (c.respond_to?(:title) ? c.title : nil) || c.try(:summary),
          channel: c.channel,
          status: c.status,
          risk_level: c.risk_level,
          last_message_at: c.last_message_at,
          created_at: c.created_at
        }
      }
    end

    def show
      conversation = current_user.conversations.find(params[:id])

      msgs =
        conversation.messages
                    .order(created_at: :asc)
                    .limit(250)

      render json: {
        conversation: {
          id: conversation.id,
          title: (conversation.respond_to?(:title) ? conversation.title : nil) || conversation.try(:summary),
          channel: conversation.channel,
          status: conversation.status,
          risk_level: conversation.risk_level,
          last_message_at: conversation.last_message_at,
          created_at: conversation.created_at
        },
        messages: msgs.map { |m|
          {
            id: m.id,
            sender_type: m.sender_type,
            content: m.content,
            content_type: m.content_type,
            risk_level: m.risk_level,
            created_at: m.created_at
          }
        }
      }
    end

    private

    def sanitize_sql_like(string)
      string.to_s.gsub(/[\\%_]/) { |x| "\\#{x}" }
    end
  end
end
