class AddPhoneVerificationFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :phone_verified_at, :datetime
    add_column :users, :phone_verification_code_digest, :string
    add_column :users, :phone_verification_sent_at, :datetime
    add_column :users, :phone_verification_attempts, :integer, default: 0, null: false
    add_column :users, :phone_verification_pending_phone, :string

    add_index :users, :phone_verification_pending_phone
    add_index :users, :phone, unique: true
  end
end