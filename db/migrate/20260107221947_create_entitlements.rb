class CreateEntitlements < ActiveRecord::Migration[7.2]
  def change
    create_table :entitlements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key
      t.boolean :enabled
      t.string :source
      t.datetime :expires_at

      t.timestamps
    end
  end
end
