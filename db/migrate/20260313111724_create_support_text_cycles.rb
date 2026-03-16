class CreateSupportTextCycles < ActiveRecord::Migration[7.2]
  def change
    create_table :support_text_cycles do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :messages_used
      t.integer :images_used
      t.datetime :cycle_start_at
      t.datetime :cycle_end_at

      t.timestamps
    end
  end
end
