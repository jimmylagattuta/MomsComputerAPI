class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :sender_type
      t.integer :sender_id
      t.text :content
      t.string :content_type
      t.string :risk_level
      t.string :ai_model
      t.string :ai_prompt_version
      t.decimal :ai_confidence
      t.json :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
