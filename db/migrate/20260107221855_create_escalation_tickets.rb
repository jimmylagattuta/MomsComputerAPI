class CreateEscalationTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :escalation_tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string :status
      t.string :priority
      t.integer :assigned_agent_id
      t.string :reason
      t.text :summary
      t.text :resolution_notes
      t.datetime :first_response_at
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
