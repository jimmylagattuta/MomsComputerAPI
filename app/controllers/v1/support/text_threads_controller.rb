# app/controllers/v1/support/text_threads_controller.rb
class V1::Support::TextThreadsController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!
  before_action :require_support_agent!

  def index
    threads = SupportTextThread.open_threads.order(last_message_at: :desc)

    Rails.logger.info(
      "[TextMomAdminBadge] index " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_count=#{threads.size}"
    )

    serialized_threads = threads.map { |thread| serialize_thread(thread) }
    total_unread_count = serialized_threads.sum { |thread| thread[:text_mom_unread_count].to_i }

    Rails.logger.info(
      "[TextMomAdminBadge] index count " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_count=#{serialized_threads.size} " \
      "text_mom_unread_count=#{total_unread_count}"
    )

    render json: {
      threads: serialized_threads,
      text_mom_unread_count: total_unread_count
    }, status: :ok
  end

  def show
    thread = SupportTextThread.find(params[:id])

    Rails.logger.info(
      "[TextMomAdminBadge] show before read " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "thread_user_id=#{thread.user_id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect}"
    )

    mark_thread_read_for_support!(thread)

    thread.reload

    Rails.logger.info(
      "[TextMomAdminBadge] show after read " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "thread_user_id=#{thread.user_id} " \
      "user_unread=#{thread.user_unread.inspect} " \
      "support_unread=#{thread.support_unread.inspect} " \
      "count=#{support_unread_count(thread)}"
    )

    render json: {
      thread: serialize_thread(thread),
      text_mom_unread_count: total_support_unread_count
    }, status: :ok
  end

  def update
    thread = SupportTextThread.find(params[:id])

    updates = {}
    updates[:priority] = params[:priority] if params[:priority].present?
    updates[:status] = params[:status] if params[:status].present?

    thread.update!(updates) if updates.any?

    Rails.logger.info(
      "[TextMomAdminBadge] update " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id} " \
      "updates=#{updates.keys.join(",")}"
    )

    render json: {
      thread: serialize_thread(thread.reload),
      text_mom_unread_count: total_support_unread_count
    }, status: :ok
  end

  def assign
    thread = SupportTextThread.find(params[:id])

    thread.update!(
      assigned_agent_id: current_user.id,
      assigned_agent_name: support_agent_display_name
    )

    Rails.logger.info(
      "[TextMomAdminBadge] assign " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id}"
    )

    render json: {
      thread: serialize_thread(thread.reload),
      text_mom_unread_count: total_support_unread_count
    }, status: :ok
  end

  def close
    thread = SupportTextThread.find(params[:id])
    thread.close!

    Rails.logger.info(
      "[TextMomAdminBadge] close " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id}"
    )

    render json: {
      thread: serialize_thread(thread.reload),
      text_mom_unread_count: total_support_unread_count
    }, status: :ok
  end

  def block
    thread = SupportTextThread.find(params[:id])
    thread.block!

    Rails.logger.info(
      "[TextMomAdminBadge] block " \
      "agent_id=#{current_user.id} " \
      "role=#{current_user.role} " \
      "thread_id=#{thread.id}"
    )

    render json: {
      thread: serialize_thread(thread.reload),
      text_mom_unread_count: total_support_unread_count
    }, status: :ok
  end

  private

  def require_support_agent!
    head :forbidden unless support_agent?
  end

  def support_agent?
    current_user&.role == "admin" || current_user&.role == "super_admin" || current_user&.admin?
  end

  def support_agent_display_name
    if current_user.respond_to?(:name) && current_user.name.present?
      current_user.name
    elsif [current_user.first_name, current_user.last_name].compact.join(" ").strip.present?
      [current_user.first_name, current_user.last_name].compact.join(" ").strip
    else
      current_user.email
    end
  end

  def mark_thread_read_for_support!(thread)
    return unless thread.support_unread == true

    thread.update!(support_unread: false)
  end

  def support_unread_count(thread)
    thread.support_unread == true ? 1 : 0
  end

  def total_support_unread_count
    SupportTextThread.open_threads.where(support_unread: true).count
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
      user_unread: thread.user_unread == true,
      support_unread: thread.support_unread == true,
      text_mom_unread_count: support_unread_count(thread)
    }
  end
end