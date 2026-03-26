class SupportTextThreadChannel < ApplicationCable::Channel
  def subscribed
    thread = SupportTextThread.find_by(id: params[:thread_id])

    unless thread
      Rails.logger.warn("[Cable] Thread not found: #{params[:thread_id]}")
      reject
      return
    end

    unless allowed_for_thread?(thread)
      Rails.logger.warn("[Cable] Unauthorized thread access: user=#{current_user&.id}, thread=#{thread.id}")
      reject
      return
    end

    stream_for thread
  end

  private

  def allowed_for_thread?(thread)
    return true if current_user&.role == "admin"

    thread.user_id == current_user&.id
  end
end