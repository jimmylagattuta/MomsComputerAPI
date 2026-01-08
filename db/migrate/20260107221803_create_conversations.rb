class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :channel
      t.string :status
      t.string :risk_level
      t.text :summary
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
