class AddIndexesToSupportTextTables < ActiveRecord::Migration[7.2]
  def change
    add_index :support_text_cycles,
              [:user_id, :cycle_start_at, :cycle_end_at],
              name: "idx_support_text_cycles_user_range"

    add_index :support_text_threads, :public_token, unique: true
    add_index :support_text_threads, :status
    add_index :support_text_threads, :assigned_agent_id
    add_index :support_text_threads, :last_message_at

    add_index :support_text_messages, :direction
    add_index :support_text_messages, :status
    add_index :support_text_messages, :author_agent_id
    add_index :support_text_messages,
              [:support_text_thread_id, :created_at],
              name: "idx_support_text_messages_thread_created"
  end
end