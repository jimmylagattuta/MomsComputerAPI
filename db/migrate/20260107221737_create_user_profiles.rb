class CreateUserProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :zip
      t.string :country
      t.text :emergency_notes
      t.text :hearing_vision_notes
      t.string :tech_skill_level
      t.string :device_os_preference
      t.string :caregiver_relationship
      t.boolean :caregiver_consent_on_file

      t.timestamps
    end
  end
end
