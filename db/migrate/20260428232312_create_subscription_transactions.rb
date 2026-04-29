class CreateSubscriptionTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscription_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :subscription, null: true, foreign_key: true
      t.references :revenuecat_event, null: true, foreign_key: true
      t.string :provider
      t.string :event_type
      t.string :product_id
      t.string :entitlement_key
      t.string :transaction_id
      t.string :original_transaction_id
      t.string :store
      t.string :environment
      t.integer :price_cents
      t.string :currency
      t.datetime :purchased_at

      t.timestamps
    end

    add_index :subscription_transactions, :transaction_id, unique: true
    add_index :subscription_transactions, :original_transaction_id
    add_index :subscription_transactions, :product_id
    add_index :subscription_transactions, :store
    add_index :subscription_transactions, :environment
    add_index :subscription_transactions, :purchased_at
    add_index :subscription_transactions, [:user_id, :purchased_at]
  end
end