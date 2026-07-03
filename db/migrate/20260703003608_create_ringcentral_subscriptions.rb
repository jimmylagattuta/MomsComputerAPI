class CreateRingcentralSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :ringcentral_subscriptions do |t|
      t.string :subscription_id, null: false
      t.string :status
      t.jsonb :event_filters, null: false, default: []
      t.string :delivery_transport_type
      t.string :delivery_address
      t.integer :expires_in
      t.datetime :expiration_time
      t.datetime :creation_time
      t.datetime :last_seen_at
      t.datetime :last_renewed_at
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :ringcentral_subscriptions, :subscription_id, unique: true
    add_index :ringcentral_subscriptions, :status
    add_index :ringcentral_subscriptions, :expiration_time
    add_index :ringcentral_subscriptions, :delivery_address
  end
end
