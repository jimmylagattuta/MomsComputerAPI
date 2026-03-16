# app/services/support_text_thread_provisioner.rb
class SupportTextThreadProvisioner
  RECENT_WINDOW = 24.hours

  def self.call(user:)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    existing = recent_active_thread
    return existing if existing.present?

    cycle = SupportTextCycle.current_or_create_for!(@user)

    thread = @user.support_text_threads.create!(
      support_text_cycle: cycle,
      status: "active",
      started_at: Time.current,
      last_message_at: Time.current,
      support_identity_label: support_identity_label,
      support_identity_email: @user.email,
      support_identity_user_ref: "User ##{@user.id}",
      support_identity_snapshot: support_identity_snapshot,
      support_unread: true,
      user_unread: false
    )

    send_intro_message!(thread)

    thread
  end

  private

  def recent_active_thread
    @user
      .support_text_threads
      .active
      .where(
        "COALESCE(last_message_at, started_at, created_at) >= ?",
        RECENT_WINDOW.ago
      )
      .order(Arel.sql("COALESCE(last_message_at, started_at, created_at) DESC"))
      .first
  end

  def support_identity_label
    [
      @user.try(:first_name),
      @user.try(:last_name)
    ].compact.join(" ").strip.presence || @user.email || "Unknown User"
  end

  def support_identity_snapshot
    {
      name: support_identity_label,
      email: @user.email,
      user_ref: "User ##{@user.id}",
      created_at: Time.current.iso8601
    }
  end

  def send_intro_message!(thread)
    body = <<~TEXT.strip
      [Mom's Computer]
      #{thread.support_identity_label} | #{thread.support_identity_email} | #{thread.support_identity_user_ref}
      Thread: #{thread.public_token}
    TEXT

    thread.support_text_messages.create!(
      user: @user,
      direction: "system",
      status: "sent",
      body: body,
      intro_message: true,
      sent_at: Time.current,
      visible_to_user: false
    )

    thread.update!(intro_sent: true)
  end
end