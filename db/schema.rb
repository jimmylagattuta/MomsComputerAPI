# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_01_09_171248) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "attachment_type"
    t.string "filename"
    t.string "content_type"
    t.integer "byte_size"
    t.string "sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_attachments_on_message_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "event_type"
    t.string "ip"
    t.string "user_agent"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "blocked_artifacts", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "reason"
    t.text "redacted_content"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_blocked_artifacts_on_message_id"
  end

  create_table "consent_records", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "kind"
    t.boolean "granted"
    t.datetime "granted_at"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_consent_records_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "channel"
    t.string "status"
    t.string "risk_level"
    t.text "summary"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "devices", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "platform"
    t.string "device_name"
    t.string "os_version"
    t.string "app_version"
    t.string "push_token"
    t.string "last_ip"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "entitlements", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "key"
    t.boolean "enabled"
    t.string "source"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_entitlements_on_user_id"
  end

  create_table "escalation_tickets", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "conversation_id", null: false
    t.string "status"
    t.string "priority"
    t.integer "assigned_agent_id"
    t.string "reason"
    t.text "summary"
    t.text "resolution_notes"
    t.datetime "first_response_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_escalation_tickets_on_conversation_id"
    t.index ["user_id"], name: "index_escalation_tickets_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.string "sender_type"
    t.integer "sender_id"
    t.text "content"
    t.string "content_type"
    t.string "risk_level"
    t.string "ai_model"
    t.string "ai_prompt_version"
    t.decimal "ai_confidence"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name"
    t.integer "price_cents"
    t.string "billing_period"
    t.integer "trial_days"
    t.boolean "active"
    t.json "features", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "revoked_tokens", force: :cascade do |t|
    t.string "jti"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "plan_id", null: false
    t.string "provider"
    t.string "provider_subscription_id"
    t.string "status"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.boolean "cancel_at_period_end"
    t.datetime "last_validated_at"
    t.text "receipt_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "trusted_contacts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.string "relationship"
    t.string "phone"
    t.string "email"
    t.string "preferred_contact_method"
    t.boolean "can_be_contacted"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_trusted_contacts_on_user_id"
  end

  create_table "user_profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "country"
    t.text "emergency_notes"
    t.text "hearing_vision_notes"
    t.string "tech_skill_level"
    t.string "device_os_preference"
    t.string "caregiver_relationship"
    t.boolean "caregiver_consent_on_file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "user", null: false
    t.string "status", default: "active", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "preferred_name"
    t.string "preferred_language"
    t.string "timezone"
    t.date "date_of_birth"
    t.boolean "marketing_opt_in", default: false
    t.datetime "terms_accepted_at"
    t.datetime "privacy_accepted_at"
    t.datetime "last_login_at"
    t.datetime "last_seen_at"
    t.integer "failed_login_count", default: 0
    t.datetime "locked_until"
    t.text "notes_internal"
    t.string "risk_flag"
    t.datetime "onboarding_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attachments", "messages"
  add_foreign_key "audit_events", "users"
  add_foreign_key "blocked_artifacts", "messages"
  add_foreign_key "consent_records", "users"
  add_foreign_key "conversations", "users"
  add_foreign_key "devices", "users"
  add_foreign_key "entitlements", "users"
  add_foreign_key "escalation_tickets", "conversations"
  add_foreign_key "escalation_tickets", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "trusted_contacts", "users"
  add_foreign_key "user_profiles", "users"
end
