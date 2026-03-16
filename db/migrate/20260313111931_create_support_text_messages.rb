class CreateSupportTextMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :support_text_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :support_text_thread, null: false, foreign_key: true
      t.string :direction
      t.string :status
      t.text :body
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at
      t.string :failure_reason
      t.boolean :intro_message
      t.boolean :visible_to_user
      t.integer :author_agent_id
      t.string :author_agent_name
      t.json :metadata

      t.timestamps
    end
  end
end
