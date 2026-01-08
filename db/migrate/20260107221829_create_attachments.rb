class CreateAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :attachments do |t|
      t.references :message, null: false, foreign_key: true
      t.string :attachment_type
      t.string :filename
      t.string :content_type
      t.integer :byte_size
      t.string :sha256

      t.timestamps
    end
  end
end
