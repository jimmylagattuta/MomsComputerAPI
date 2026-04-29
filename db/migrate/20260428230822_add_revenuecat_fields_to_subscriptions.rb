class AddRevenuecatFieldsToSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :subscriptions, :revenuecat_app_user_id, :string
    add_column :subscriptions, :revenuecat_original_app_user_id, :string
    add_column :subscriptions, :product_id, :string
    add_column :subscriptions, :entitlement_key, :string
    add_column :subscriptions, :store, :string
    add_column :subscriptions, :environment, :string
    add_column :subscriptions, :transaction_id, :string
    add_column :subscriptions, :original_transaction_id, :string
    add_column :subscriptions, :price_cents, :integer
    add_column :subscriptions, :currency, :string
    add_column :subscriptions, :billing_period, :string
    add_column :subscriptions, :cancelled_at, :datetime
    add_column :subscriptions, :billing_issue_at, :datetime
    add_column :subscriptions, :expired_at, :datetime

    add_index :subscriptions, :revenuecat_app_user_id
    add_index :subscriptions, :product_id
    add_index :subscriptions, :status
    add_index :subscriptions, :store
    add_index :subscriptions, :environment
    add_index :subscriptions, :transaction_id
    add_index :subscriptions, :original_transaction_id
  end
end