class CreateSupportCallCycles < ActiveRecord::Migration[7.0]
  def change
    create_table :support_call_cycles do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :calls_allowed, null: false, default: 3
      t.integer :calls_used, null: false, default: 0
      t.datetime :cycle_start_at, null: false
      t.datetime :cycle_end_at, null: false

      t.timestamps
    end

    add_index :support_call_cycles, [:user_id, :cycle_start_at, :cycle_end_at], name: "index_support_call_cycles_on_user_and_cycle_range"
  end
end