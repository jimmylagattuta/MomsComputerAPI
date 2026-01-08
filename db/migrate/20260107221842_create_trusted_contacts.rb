class CreateTrustedContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :trusted_contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :relationship
      t.string :phone
      t.string :email
      t.string :preferred_contact_method
      t.boolean :can_be_contacted
      t.text :notes

      t.timestamps
    end
  end
end
