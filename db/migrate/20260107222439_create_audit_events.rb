class CreateAuditEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_type
      t.string :ip
      t.string :user_agent
      t.json :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
