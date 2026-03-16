# app/controllers/v1/support_text_threads_controller.rb
class V1::SupportTextThreadsController < ApplicationController
  include JwtAuth
  include Rails.application.routes.url_helpers

  before_action :authenticate_user!

  def current
    thread = SupportTextThreadProvisioner.call(user: current_user)
    render json: { thread: serialize_thread(thread) }, status: :ok
  end

  def create
    thread = SupportTextThreadProvisioner.call(user: current_user)
    render json: { thread: serialize_thread(thread) }, status: :created
  end

  def index
    limit = params[:limit].presence.to_i
    limit = 20 if limit <= 0
    limit = 50 if limit > 50

    q = params[:q].to_s.strip

    scope = current_user.support_text_threads

    if q.present?
      pattern = "%#{sanitize_sql_like(q.downcase)}%"

      scope =
        scope.left_joins(:support_text_messages)
             .where(
               "LOWER(COALESCE(support_text_threads.subject, '')) LIKE :pattern
                OR LOWER(COALESCE(support_text_threads.assigned_agent_name, '')) LIKE :pattern
                OR LOWER(COALESCE(support_text_messages.body, '')) LIKE :pattern",
               pattern: pattern
             )
             .distinct
    end

    threads =
      scope.order(Arel.sql("COALESCE(support_text_threads.last_message_at, support_text_threads.created_at) DESC"))
           .limit(limit)

    render json: threads.map { |thread| serialize_thread(thread) }, status: :ok
  end

  def show
    thread = current_user.support_text_threads.find(params[:id])

    messages =
      thread.support_text_messages
            .where(visible_to_user: [true, nil])
            .order(created_at: :asc)
            .limit(250)

    render json: {
      thread: serialize_thread(thread),
      messages: messages.map { |message| serialize_message(message) }
    }, status: :ok
  end

  private

  def serialize_thread(thread)
    {
      id: thread.id,
      public_token: thread.public_token,
      status: thread.status,
      subject: thread.subject,
      priority: thread.priority,
      assigned_agent_name: thread.assigned_agent_name,
      started_at: thread.started_at,
      last_message_at: thread.last_message_at,
      cooldown_until: thread.cooldown_until,
      created_at: thread.created_at,
      updated_at: thread.updated_at
    }
  end

  def serialize_message(message)
    {
      id: message.id,
      direction: message.direction,
      status: message.status,
      body: message.body,
      created_at: message.created_at,
      sent_at: message.sent_at,
      delivered_at: message.delivered_at,
      read_at: message.read_at,
      failed_at: message.failed_at,
      failure_reason: message.failure_reason,
      intro_message: message.intro_message,
      visible_to_user: message.visible_to_user,
      author_agent_name: message.author_agent_name,
      images: message_image_payloads(message)
    }
  end

  def message_image_payloads(message)
    return [] unless message.respond_to?(:images) && message.images.attached?

    message.images.map do |img|
      {
        id: img.id,
        url: rails_blob_url(
          img,
          host: request.base_url,
          disposition: "inline"
        ),
        filename: img.filename.to_s,
        content_type: img.content_type,
        byte_size: img.byte_size
      }
    end
  end

  def sanitize_sql_like(string)
    string.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
  end
end