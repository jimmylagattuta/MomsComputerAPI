class CreateConsentRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :consent_records do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind
      t.boolean :granted
      t.datetime :granted_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
