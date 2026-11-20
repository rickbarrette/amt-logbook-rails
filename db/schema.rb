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

ActiveRecord::Schema[8.1].define(version: 2026_11_21_020000) do
  create_table "aircraft", force: :cascade do |t|
    t.string "n_number", null: false
    t.string "serial_number"
    t.string "manufacturer"
    t.string "model"
    t.integer "year_manufactured"
    t.string "aircraft_type"
    t.string "engine_type"
    t.string "engine_manufacturer"
    t.string "engine_model"
    t.integer "engines_count"
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["n_number"], name: "index_aircraft_on_n_number", unique: true
  end

  create_table "airport_updates", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.integer "created_count"
    t.integer "updated_count"
    t.integer "removed_count"
    t.text "error"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "airports", force: :cascade do |t|
    t.string "ident", null: false
    t.string "code", null: false
    t.string "gps_code"
    t.string "local_code"
    t.string "iata"
    t.string "name", null: false
    t.string "kind"
    t.string "municipality"
    t.string "region"
    t.string "country"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_airports_on_code"
    t.index ["gps_code"], name: "index_airports_on_gps_code"
    t.index ["iata"], name: "index_airports_on_iata"
    t.index ["ident"], name: "index_airports_on_ident", unique: true
    t.index ["local_code"], name: "index_airports_on_local_code"
  end

  create_table "entry_imports", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "kind", null: false
    t.string "filename"
    t.text "data", null: false
    t.json "mapping", default: {}, null: false
    t.json "options", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "created_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.json "problems", default: [], null: false
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_entry_imports_on_user_id"
  end

  create_table "entry_signatures", force: :cascade do |t|
    t.integer "work_entry_id", null: false
    t.integer "user_id"
    t.string "signer_name", null: false
    t.string "certificate_kind", null: false
    t.string "certificate_number", null: false
    t.text "statement", null: false
    t.datetime "signed_at", null: false
    t.string "content_digest", null: false
    t.text "content_snapshot", null: false
    t.string "auth_method", null: false
    t.string "ip_address"
    t.string "seal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_entry_signatures_on_user_id"
    t.index ["work_entry_id"], name: "index_entry_signatures_on_work_entry_id", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "token", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "technician", default: true, null: false
    t.boolean "supervisor", default: false, null: false
    t.integer "invited_by_id"
    t.integer "user_id"
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["user_id"], name: "index_invitations_on_user_id"
  end

  create_table "passkeys", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "name", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
    t.index ["user_id"], name: "index_passkeys_on_user_id"
  end

  create_table "registry_imports", force: :cascade do |t|
    t.integer "user_id"
    t.string "filename"
    t.integer "records_count"
    t.string "status", default: "pending", null: false
    t.text "error"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_registry_imports_on_user_id"
  end

  create_table "registry_records", force: :cascade do |t|
    t.string "n_number", null: false
    t.string "serial_number"
    t.string "manufacturer"
    t.string "model"
    t.integer "year_manufactured"
    t.string "aircraft_type"
    t.string "engine_type"
    t.string "engine_manufacturer"
    t.string "engine_model"
    t.integer "engines_count"
    t.integer "seats"
    t.string "status_code"
    t.index ["n_number"], name: "index_registry_records_on_n_number", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "via_sso", default: false, null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "supervisions", force: :cascade do |t|
    t.integer "technician_id", null: false
    t.integer "supervisor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supervisor_id"], name: "index_supervisions_on_supervisor_id"
    t.index ["technician_id", "supervisor_id"], name: "index_supervisions_on_technician_id_and_supervisor_id", unique: true
    t.index ["technician_id"], name: "index_supervisions_on_technician_id"
  end

  create_table "timers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "aircraft_id"
    t.integer "work_entry_id"
    t.string "category"
    t.string "description"
    t.datetime "started_at", null: false
    t.datetime "running_since"
    t.integer "accumulated_seconds", default: 0, null: false
    t.datetime "stopped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aircraft_id"], name: "index_timers_on_aircraft_id"
    t.index ["user_id", "stopped_at"], name: "index_timers_on_user_id_and_stopped_at"
    t.index ["user_id"], name: "index_timers_on_user_id"
    t.index ["work_entry_id"], name: "index_timers_on_work_entry_id"
  end

  create_table "user_certificates", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "kind", null: false
    t.string "number", null: false
    t.date "expires_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_certificates_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "technician", default: true, null: false
    t.boolean "supervisor", default: false, null: false
    t.string "time_zone"
    t.string "rating_goal", default: "both", null: false
    t.date "experience_started_on"
    t.string "otp_secret"
    t.datetime "otp_enabled_at"
    t.datetime "otp_last_used_at"
    t.json "otp_recovery_codes"
    t.integer "failed_sign_ins", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "disabled_at"
    t.datetime "last_signed_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sso_uid"
    t.string "webauthn_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["sso_uid"], name: "index_users_on_sso_uid", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  create_table "work_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "aircraft_id"
    t.integer "supervisor_id"
    t.date "performed_on", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "minutes", null: false
    t.string "category", null: false
    t.string "ata_chapter"
    t.json "subject_areas", default: [], null: false
    t.text "description", null: false
    t.string "reference"
    t.string "location"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.text "returned_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "supervisor_name"
    t.string "supervisor_certificate"
    t.integer "entry_import_id"
    t.json "import_details"
    t.index ["aircraft_id"], name: "index_work_entries_on_aircraft_id"
    t.index ["entry_import_id"], name: "index_work_entries_on_entry_import_id"
    t.index ["supervisor_id", "status"], name: "index_work_entries_on_supervisor_id_and_status"
    t.index ["supervisor_id"], name: "index_work_entries_on_supervisor_id"
    t.index ["user_id", "performed_on"], name: "index_work_entries_on_user_id_and_performed_on"
    t.index ["user_id"], name: "index_work_entries_on_user_id"
  end

  add_foreign_key "entry_imports", "users"
  add_foreign_key "entry_signatures", "users"
  add_foreign_key "entry_signatures", "work_entries"
  add_foreign_key "invitations", "users"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "passkeys", "users"
  add_foreign_key "registry_imports", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "supervisions", "users", column: "supervisor_id"
  add_foreign_key "supervisions", "users", column: "technician_id"
  add_foreign_key "timers", "aircraft"
  add_foreign_key "timers", "users"
  add_foreign_key "timers", "work_entries"
  add_foreign_key "user_certificates", "users"
  add_foreign_key "work_entries", "aircraft"
  add_foreign_key "work_entries", "entry_imports", on_delete: :nullify
  add_foreign_key "work_entries", "users"
  add_foreign_key "work_entries", "users", column: "supervisor_id"
end
