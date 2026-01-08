# app/controllers/v1/escalations_controller.rb
module V1
  class EscalationsController < ApplicationController
    include JwtAuth

    # POST /v1/escalations
    # Body: { conversation_id (optional), reason (optional), summary (optional), priority (optional) }
    def create
      conversation = nil
      if params[:conversation_id].present?
        conversation = current_user.conversations.find(params[:conversation_id])
      end

      ticket = EscalationTicket.create!(
        user: current_user,
        conversation: conversation,
        status: "open",
        priority: params[:priority].presence || "normal",
        reason: params[:reason].presence || "user_requested_help",
        summary: params[:summary].presence || "User requested escalation."
      )

      render json: {
        escalation_ticket_id: ticket.id,
        status: ticket.status,
        priority: ticket.priority,
        reason: ticket.reason
      }, status: :created
    end
  end
end