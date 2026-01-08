class CreateDevices < ActiveRecord::Migration[7.2]
  def change
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :platform
      t.string :device_name
      t.string :os_version
      t.string :app_version
      t.string :push_token
      t.string :last_ip
      t.datetime :last_seen_at

      t.timestamps
    end
  end
end
