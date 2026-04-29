class CreateRevenuecatEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :revenuecat_events do |t|
      t.references :user, null: true, foreign_key: true
      t.string :event_id
      t.string :event_type
      t.string :app_user_id
      t.string :product_id
      t.string :entitlement_key
      t.string :transaction_id
      t.string :original_transaction_id
      t.string :store
      t.string :environment
      t.integer :price_cents
      t.string :currency
      t.datetime :purchased_at
      t.datetime :expiration_at
      t.json :raw_payload, default: {}, null: false

      t.timestamps
    end

    add_index :revenuecat_events, :event_id, unique: true
    add_index :revenuecat_events, :app_user_id
    add_index :revenuecat_events, :event_type
    add_index :revenuecat_events, :transaction_id
    add_index :revenuecat_events, :original_transaction_id
    add_index :revenuecat_events, :created_at
  end
end