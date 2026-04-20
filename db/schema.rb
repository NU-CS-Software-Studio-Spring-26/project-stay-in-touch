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

ActiveRecord::Schema[8.1].define(version: 2026_04_20_192508) do
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
    t.string "medium", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.decimal "frequency_weeks", precision: 5, scale: 2, default: "4.0", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "preferred_end_hour", default: 21, null: false
    t.integer "preferred_start_hour", default: 9, null: false
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(email)", name: "index_people_on_lower_email", unique: true
  end

  add_foreign_key "event_participants", "events"
  add_foreign_key "event_participants", "people"
end
