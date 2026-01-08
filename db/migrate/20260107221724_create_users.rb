class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.string :role, null: false, default: "user"
      t.string :status, null: false, default: "active"

      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :preferred_name
      t.string :preferred_language
      t.string :timezone
      t.date :date_of_birth

      t.boolean :marketing_opt_in, default: false
      t.datetime :terms_accepted_at
      t.datetime :privacy_accepted_at

      t.datetime :last_login_at
      t.datetime :last_seen_at
      t.integer :failed_login_count, default: 0
      t.datetime :locked_until

      t.text :notes_internal
      t.string :risk_flag
      t.datetime :onboarding_completed_at

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end