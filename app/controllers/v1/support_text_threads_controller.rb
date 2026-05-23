# app/controllers/v1/support_text_threads_controller.rb
class V1::SupportTextThreadsController < ApplicationController
  include JwtAuth
  include Rails.application.routes.url_helpers

  before_action :authenticate_user!

  def current
    thread = SupportTextThreadProvisioner.call(user: current_user)
    serialized_thread = serialize_thread(thread)
    unread_count = unread_count_for_current_user(thread)

    Rails.logger.info(
      "[TextMomBadge] current " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "thread_user_id=#{thread.user_id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect} " \
      "count=#{unread_count}"
    )

    render json: {
      thread: serialized_thread.merge(text_mom_unread_count: unread_count),
      text_mom_unread_count: unread_count
    }, status: :ok
  end

  def create
    thread = SupportTextThreadProvisioner.call(user: current_user)
    serialized_thread = serialize_thread(thread)
    unread_count = unread_count_for_current_user(thread)

    Rails.logger.info(
      "[TextMomBadge] create " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "thread_user_id=#{thread.user_id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect} " \
      "count=#{unread_count}"
    )

    render json: {
      thread: serialized_thread.merge(text_mom_unread_count: unread_count),
      text_mom_unread_count: unread_count
    }, status: :created
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

    render json: threads.map { |thread| serialize_thread_with_current_user_count(thread) }, status: :ok
  end

  def show
    thread = current_user.support_text_threads.find(params[:id])

    mark_thread_read_for_current_user!(thread)

    messages =
      thread.support_text_messages
            .where(visible_to_user: [true, nil])
            .order(created_at: :asc)
            .limit(250)

    thread.reload

    Rails.logger.info(
      "[TextMomBadge] show/read " \
      "user_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "thread_user_id=#{thread.user_id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect} " \
      "count=#{unread_count_for_current_user(thread)}"
    )

    render json: {
      thread: serialize_thread_with_current_user_count(thread),
      messages: messages.map { |message| serialize_message(message) }
    }, status: :ok
  end

  private

  def serialize_thread_with_current_user_count(thread)
    serialize_thread(thread).merge(
      text_mom_unread_count: unread_count_for_current_user(thread)
    )
  end

  def serialize_thread(thread)
    {
      id: thread.id,
      public_token: thread.public_token,
      status: thread.status,
      subject: thread.subject,
      priority: thread.priority,
      assigned_agent_name: thread.assigned_agent_name,

      user_unread: thread.user_unread == true,
      support_unread: thread.support_unread == true,

      started_at: thread.started_at,
      last_message_at: thread.last_message_at,
      last_user_message_at: thread.last_user_message_at,
      last_support_message_at: thread.last_support_message_at,
      cooldown_until: thread.cooldown_until,
      created_at: thread.created_at,
      updated_at: thread.updated_at
    }
  end

  def unread_count_for_current_user(thread)
    if support_user?
      thread.support_unread == true ? 1 : 0
    else
      thread.user_unread == true ? 1 : 0
    end
  end

  def mark_thread_read_for_current_user!(thread)
    if support_user?
      return unless thread.support_unread == true

      thread.update!(support_unread: false)
    else
      return unless thread.user_unread == true

      thread.update!(user_unread: false)
    end
  end

  def support_user?
    current_user.role == "admin" || current_user.role == "super_admin"
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