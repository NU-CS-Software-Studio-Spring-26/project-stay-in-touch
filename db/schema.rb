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

ActiveRecord::Schema[8.1].define(version: 2026_05_25_184311) do
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

  create_table "people", force: :cascade do |t|
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
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "reset_token"
    t.datetime "reset_token_expires_at"
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_token"], name: "index_users_on_reset_token"
  end

  add_foreign_key "event_participants", "events"
  add_foreign_key "event_participants", "people"
  add_foreign_key "events", "users"
  add_foreign_key "google_credentials", "users"
  add_foreign_key "people", "users"
  add_foreign_key "person_tags", "people"
  add_foreign_key "person_tags", "tags"
  add_foreign_key "sessions", "users"
  add_foreign_key "tags", "users"
end
