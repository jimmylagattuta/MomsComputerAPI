class CreateBlockedArtifacts < ActiveRecord::Migration[7.2]
  def change
    create_table :blocked_artifacts do |t|
      t.references :message, null: false, foreign_key: true
      t.string :reason
      t.text :redacted_content
      t.json :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
