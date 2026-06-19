class CreateRevenuecatCustomerLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :revenuecat_customer_links do |t|
      t.references :user, null: true, foreign_key: true

      t.string :app_user_id, null: false
      t.string :original_app_user_id
      t.string :guest_id

      t.string :status, null: false, default: "anonymous"

      t.string :last_event_id
      t.string :last_event_type
      t.string :product_id
      t.string :entitlement_key
      t.string :store
      t.string :environment
      t.datetime :expiration_at
      t.datetime :linked_at

      t.timestamps
    end

    add_index :revenuecat_customer_links, :app_user_id, unique: true
    add_index :revenuecat_customer_links, :original_app_user_id
    add_index :revenuecat_customer_links, :guest_id
    add_index :revenuecat_customer_links, :status
    add_index :revenuecat_customer_links, [:user_id, :app_user_id]
  end
end