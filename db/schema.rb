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

ActiveRecord::Schema[8.1].define(version: 2026_06_07_000002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blocks", force: :cascade do |t|
    t.integer "blocked_id", null: false
    t.integer "blocker_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_blocks_on_blocker_id_and_blocked_id", unique: true
  end

  create_table "event_participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_participants_on_event_id"
    t.index ["person_id", "event_id"], name: "index_event_participants_on_person_id_and_event_id", unique: true
    t.index ["person_id"], name: "index_event_participants_on_person_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_minutes", default: 60, null: false
    t.string "medium", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "google_credentials", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "refresh_token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_google_credentials_on_user_id", unique: true
  end

  create_table "meeting_proposals", force: :cascade do |t|
    t.boolean "calendar_created", default: false, null: false
    t.string "calendar_event_id"
    t.string "calendar_event_link"
    t.datetime "created_at", null: false
    t.text "decision_reason"
    t.datetime "meeting_at"
    t.text "pitch"
    t.integer "recipient_id"
    t.text "recipient_profile_snapshot"
    t.integer "requester_id", null: false
    t.text "requester_profile_snapshot"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id", "created_at"], name: "index_meeting_proposals_on_recipient_id_and_created_at"
    t.index ["recipient_id"], name: "index_meeting_proposals_on_recipient_id"
    t.index ["requester_id", "created_at"], name: "index_meeting_proposals_on_requester_id_and_created_at"
    t.index ["requester_id", "recipient_id", "created_at"], name: "idx_on_requester_id_recipient_id_created_at_18774dba88"
    t.index ["requester_id"], name: "index_meeting_proposals_on_requester_id"
  end

  create_table "people", force: :cascade do |t|
    t.date "birthday"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "favorite", default: false, null: false
    t.decimal "frequency_weeks", precision: 5, scale: 2, default: "4.0", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "preferred_end_hour", default: 21, null: false
    t.integer "preferred_start_hour", default: 9, null: false
    t.date "snoozed_until"
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "email"], name: "index_people_on_user_id_and_email", unique: true
    t.index ["user_id", "favorite"], name: "index_people_on_user_id_and_favorite"
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "person_facts", force: :cascade do |t|
    t.text "body", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.date "noted_at"
    t.integer "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "created_at"], name: "index_person_facts_on_person_id_and_created_at"
    t.index ["person_id"], name: "index_person_facts_on_person_id"
  end

  create_table "person_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "person_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "tag_id"], name: "index_person_tags_on_person_id_and_tag_id", unique: true
    t.index ["person_id"], name: "index_person_tags_on_person_id"
    t.index ["tag_id"], name: "index_person_tags_on_tag_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.integer "channel_hash", limit: 8, null: false
    t.datetime "created_at", null: false
    t.binary "payload", limit: 536870912, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email", null: false
    t.boolean "matchmaking_enabled", default: false, null: false
    t.text "meeting_interests"
    t.string "password_digest", null: false
    t.string "reset_token"
    t.datetime "reset_token_expires_at"
    t.datetime "terms_accepted_at"
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["matchmaking_enabled"], name: "index_users_on_matchmaking_enabled"
    t.index ["reset_token"], name: "index_users_on_reset_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blocks", "users", column: "blocked_id"
  add_foreign_key "blocks", "users", column: "blocker_id"
  add_foreign_key "event_participants", "events"
  add_foreign_key "event_participants", "people"
  add_foreign_key "events", "users"
  add_foreign_key "google_credentials", "users"
  add_foreign_key "meeting_proposals", "users", column: "recipient_id"
  add_foreign_key "meeting_proposals", "users", column: "requester_id"
  add_foreign_key "people", "users"
  add_foreign_key "person_facts", "people"
  add_foreign_key "person_tags", "people"
  add_foreign_key "person_tags", "tags"
  add_foreign_key "sessions", "users"
  add_foreign_key "tags", "users"
end
