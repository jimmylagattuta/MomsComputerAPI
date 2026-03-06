class CreateSupportCallSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :support_call_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :support_call_cycle, null: false, foreign_key: true
      t.string :twilio_call_sid
      t.string :status
      t.datetime :started_at
      t.datetime :answered_at
      t.datetime :ended_at
      t.integer :duration_seconds
      t.boolean :chargeable, null: false, default: false
      t.datetime :charged_at
      t.string :failure_reason

      t.timestamps
    end

    add_index :support_call_sessions, :twilio_call_sid, unique: true
    add_index :support_call_sessions, :status
    add_index :support_call_sessions, :chargeable
  end
end