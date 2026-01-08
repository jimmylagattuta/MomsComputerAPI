class CreatePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :plans do |t|
      t.string :name
      t.integer :price_cents
      t.string :billing_period
      t.integer :trial_days
      t.boolean :active
      t.json :features, null: false, default: {}

      t.timestamps
    end
  end
end
