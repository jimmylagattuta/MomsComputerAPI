class AddRingcentralFieldsToSupportCallSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :support_call_sessions, :ringcentral_telephony_session_id, :string
    add_column :support_call_sessions, :ringcentral_party_id, :string
    add_column :support_call_sessions, :ringcentral_status, :string
    add_column :support_call_sessions, :caller_phone, :string
    add_column :support_call_sessions, :to_phone, :string
    add_column :support_call_sessions, :ringcentral_extension_id, :string
    add_column :support_call_sessions, :ringcentral_to_name, :string
    add_column :support_call_sessions, :forwarded_to, :string
    add_column :support_call_sessions, :blocked_reason, :string
    add_column :support_call_sessions, :ringcentral_raw_payload, :json, default: {}, null: false

    add_index :support_call_sessions, :ringcentral_telephony_session_id
    add_index :support_call_sessions, :ringcentral_party_id
    add_index :support_call_sessions, :caller_phone
    add_index :support_call_sessions, :blocked_reason

    add_index :support_call_sessions,
              [:ringcentral_telephony_session_id, :ringcentral_party_id],
              unique: true,
              name: "index_support_calls_on_rc_session_and_party"
  end
end