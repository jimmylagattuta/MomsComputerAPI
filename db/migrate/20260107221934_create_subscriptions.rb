class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.string :provider
      t.string :provider_subscription_id
      t.string :status
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :cancel_at_period_end
      t.datetime :last_validated_at
      t.text :receipt_data

      t.timestamps
    end
  end
end
