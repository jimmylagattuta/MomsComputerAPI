# app/controllers/v1/support/text_threads_controller.rb
class V1::Support::TextThreadsController < ApplicationController
  include JwtAuth
  
  before_action :authenticate_user!
  before_action :require_support_agent!

  def index
    threads = SupportTextThread.open_threads.order(last_message_at: :desc)

    render json: {
      threads: threads.map { |thread| serialize_thread(thread) }
    }, status: :ok
  end

  def show
    thread = SupportTextThread.find(params[:id])

    thread.update!(support_unread: 0)

    render json: {
      thread: serialize_thread(thread.reload)
    }, status: :ok
  end

  def update
    thread = SupportTextThread.find(params[:id])

    updates = {}
    updates[:priority] = params[:priority] if params[:priority].present?
    updates[:status] = params[:status] if params[:status].present?

    thread.update!(updates) if updates.any?

    render json: { thread: serialize_thread(thread) }, status: :ok
  end

  def assign
    thread = SupportTextThread.find(params[:id])

    thread.update!(
      assigned_agent_id: current_user.id,
      assigned_agent_name: current_user.try(:name).presence || current_user.email
    )

    render json: { thread: serialize_thread(thread) }, status: :ok
  end

  def close
    thread = SupportTextThread.find(params[:id])
    thread.close!

    render json: { thread: serialize_thread(thread) }, status: :ok
  end

  def block
    thread = SupportTextThread.find(params[:id])
    thread.block!

    render json: { thread: serialize_thread(thread) }, status: :ok
  end

  private

  def require_support_agent!
    head :forbidden unless current_user&.admin?
  end

  def serialize_thread(thread)
    {
      id: thread.id,
      public_token: thread.public_token,
      status: thread.status,
      priority: thread.priority,
      assigned_agent_id: thread.assigned_agent_id,
      assigned_agent_name: thread.assigned_agent_name,
      support_identity_snapshot: thread.support_identity_snapshot,
      last_message_at: thread.last_message_at,
      last_user_message_at: thread.last_user_message_at,
      last_support_message_at: thread.last_support_message_at,
      user_unread: thread.user_unread,
      support_unread: thread.support_unread
    }
  end
end