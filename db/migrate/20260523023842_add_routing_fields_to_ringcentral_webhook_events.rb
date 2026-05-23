class AddRoutingFieldsToRingcentralWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :ringcentral_webhook_events, :to_phone, :string
    add_column :ringcentral_webhook_events, :extension_id, :string
    add_column :ringcentral_webhook_events, :to_name, :string
    add_column :ringcentral_webhook_events, :processed, :boolean, default: false, null: false
    add_column :ringcentral_webhook_events, :processed_at, :datetime
    add_column :ringcentral_webhook_events, :processing_result, :string

    add_index :ringcentral_webhook_events, :to_phone
    add_index :ringcentral_webhook_events, :extension_id
    add_index :ringcentral_webhook_events, :processed
    add_index :ringcentral_webhook_events,
              [:telephony_session_id, :party_id, :processed],
              name: "index_rc_events_on_session_party_processed"
  end
end