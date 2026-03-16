class CreateSupportTextThreads < ActiveRecord::Migration[7.2]
  def change
    create_table :support_text_threads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :support_text_cycle, null: false, foreign_key: true
      t.string :status
      t.string :public_token
      t.string :subject
      t.string :priority
      t.string :assigned_agent_name
      t.integer :assigned_agent_id
      t.string :support_identity_label
      t.string :support_identity_email
      t.string :support_identity_user_ref
      t.json :support_identity_snapshot
      t.datetime :started_at
      t.datetime :last_message_at
      t.datetime :last_user_message_at
      t.datetime :last_support_message_at
      t.datetime :closed_at
      t.datetime :blocked_at
      t.datetime :cooldown_until
      t.boolean :intro_sent
      t.boolean :blocked
      t.boolean :user_unread
      t.boolean :support_unread
      t.json :metadata

      t.timestamps
    end
  end
end
