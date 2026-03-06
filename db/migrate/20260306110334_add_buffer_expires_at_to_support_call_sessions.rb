class AddBufferExpiresAtToSupportCallSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :support_call_sessions, :buffer_expires_at, :datetime

    add_index :support_call_sessions, :buffer_expires_at
  end
end