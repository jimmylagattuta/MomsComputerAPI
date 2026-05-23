class CreateRingcentralWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :ringcentral_webhook_events do |t|
      t.string :event_type
      t.string :telephony_session_id
      t.string :party_id
      t.string :direction
      t.string :status
      t.string :caller_phone
      t.json :raw_payload, default: {}, null: false

      t.timestamps
    end

    add_index :ringcentral_webhook_events, :telephony_session_id
    add_index :ringcentral_webhook_events, :party_id
    add_index :ringcentral_webhook_events, :caller_phone
    add_index :ringcentral_webhook_events, :status
  end
end