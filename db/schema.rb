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

ActiveRecord::Schema[8.0].define(version: 2025_08_13_081442) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "file_upload_permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "allowed_paths", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_file_upload_permissions_on_user_id"
  end

  create_table "file_uploads", force: :cascade do |t|
    t.string "file"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "group_servers", force: :cascade do |t|
    t.bigint "server_id"
    t.bigint "group_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["group_id"], name: "idx_17095_index_group_servers_on_group_id"
    t.index ["server_id"], name: "idx_17095_index_group_servers_on_server_id"
  end

  create_table "group_users", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "group_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "expires_at", precision: nil
    t.index ["expires_at"], name: "idx_17101_index_group_users_on_expires_at"
    t.index ["group_id"], name: "idx_17101_index_group_users_on_group_id"
    t.index ["user_id"], name: "idx_17101_index_group_users_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "idx_17086_index_groups_on_name"
  end

  create_table "hiperz_server_informations", force: :cascade do |t|
    t.bigint "server_id"
    t.bigint "hiperz_id"
    t.index ["hiperz_id"], name: "idx_17107_index_hiperz_server_informations_on_hiperz_id"
    t.index ["server_id"], name: "idx_17107_index_hiperz_server_informations_on_server_id"
  end

  create_table "locations", force: :cascade do |t|
    t.text "name"
    t.text "flag"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "log_uploads", force: :cascade do |t|
    t.bigint "reservation_id"
    t.text "file_name"
    t.text "title"
    t.text "map_name"
    t.text "status"
    t.text "url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["reservation_id"], name: "idx_17122_index_log_uploads_on_reservation_id"
  end

  create_table "map_uploads", force: :cascade do |t|
    t.text "name"
    t.text "file"
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "paypal_orders", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "product_id"
    t.text "payment_id"
    t.text "payer_id"
    t.text "status"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "gift", default: false
    t.string "type"
    t.index ["payer_id"], name: "idx_17140_index_paypal_orders_on_payer_id"
    t.index ["payment_id"], name: "idx_17140_index_paypal_orders_on_payment_id"
    t.index ["product_id"], name: "idx_17140_index_paypal_orders_on_product_id"
    t.index ["user_id"], name: "idx_17140_index_paypal_orders_on_user_id"
  end

  create_table "player_statistics", force: :cascade do |t|
    t.bigint "ping"
    t.bigint "loss"
    t.bigint "minutes_connected"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.bigint "reservation_player_id"
    t.index ["created_at"], name: "idx_17149_index_player_statistics_on_created_at"
    t.index ["loss"], name: "idx_17149_index_player_statistics_on_loss"
    t.index ["ping"], name: "idx_17149_index_player_statistics_on_ping"
    t.index ["reservation_player_id"], name: "idx_17149_index_player_statistics_on_reservation_player_id"
  end

  create_table "products", force: :cascade do |t|
    t.text "name"
    t.decimal "price", precision: 15, scale: 6, null: false
    t.bigint "days"
    t.boolean "active", default: true
    t.text "currency"
    t.boolean "grants_private_server"
    t.index ["grants_private_server"], name: "idx_17155_index_products_on_grants_private_server"
  end

  create_table "reservation_players", force: :cascade do |t|
    t.bigint "reservation_id"
    t.text "steam_uid"
    t.text "name"
    t.text "ip"
    t.float "latitude"
    t.float "longitude"
    t.boolean "whitelisted"
    t.integer "asn_number"
    t.string "asn_organization"
    t.string "asn_network"
    t.index ["asn_number"], name: "index_reservation_players_on_asn_number"
    t.index ["ip"], name: "index_reservation_players_on_ip"
    t.index ["latitude", "longitude"], name: "idx_17193_index_reservation_players_on_latitude_and_longitude"
    t.index ["reservation_id"], name: "idx_17193_index_reservation_players_on_reservation_id"
    t.index ["steam_uid"], name: "idx_17193_index_reservation_players_on_steam_uid"
  end

  create_table "reservation_statuses", force: :cascade do |t|
    t.bigint "reservation_id"
    t.text "status"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["created_at"], name: "idx_17202_index_reservation_statuses_on_created_at"
    t.index ["reservation_id"], name: "idx_17202_index_reservation_statuses_on_reservation_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "server_id"
    t.text "password"
    t.text "rcon"
    t.text "tv_password"
    t.text "tv_relaypassword"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "starts_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.boolean "provisioned", default: false
    t.boolean "ended", default: false
    t.bigint "server_config_id"
    t.bigint "whitelist_id"
    t.bigint "inactive_minute_counter", default: 0
    t.bigint "last_number_of_players", default: 0
    t.text "first_map"
    t.boolean "start_instantly", default: false
    t.boolean "end_instantly", default: false
    t.string "custom_whitelist_id"
    t.bigint "duration"
    t.boolean "auto_end", default: true
    t.text "logsecret"
    t.boolean "enable_plugins", default: false
    t.boolean "enable_arena_respawn", default: false
    t.boolean "enable_demos_tf", default: false
    t.string "gameye_location"
    t.string "sdr_ip"
    t.string "sdr_port"
    t.string "sdr_tv_port"
    t.boolean "disable_democheck", default: false
    t.text "original_password"
    t.datetime "locked_at"
    t.index ["auto_end"], name: "idx_17175_index_reservations_on_auto_end"
    t.index ["created_at"], name: "index_reservations_on_created_at"
    t.index ["custom_whitelist_id"], name: "idx_17175_index_reservations_on_custom_whitelist_id"
    t.index ["end_instantly"], name: "idx_17175_index_reservations_on_end_instantly"
    t.index ["ends_at"], name: "idx_17175_index_reservations_on_ends_at"
    t.index ["logsecret"], name: "idx_17175_index_reservations_on_logsecret"
    t.index ["server_config_id"], name: "idx_17175_index_reservations_on_server_config_id"
    t.index ["server_id", "starts_at"], name: "idx_17175_index_reservations_on_server_id_and_starts_at", unique: true
    t.index ["server_id"], name: "idx_17175_index_reservations_on_server_id"
    t.index ["start_instantly"], name: "idx_17175_index_reservations_on_start_instantly"
    t.index ["starts_at", "duration"], name: "index_reservations_on_starts_at_and_duration"
    t.index ["starts_at"], name: "idx_17175_index_reservations_on_starts_at"
    t.index ["updated_at"], name: "idx_17175_index_reservations_on_updated_at"
    t.index ["user_id"], name: "idx_17175_index_reservations_on_user_id"
    t.index ["whitelist_id"], name: "idx_17175_index_reservations_on_whitelist_id"
  end

  create_table "server_configs", force: :cascade do |t|
    t.text "file"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "hidden", default: false
    t.index ["hidden"], name: "index_server_configs_on_hidden"
  end

  create_table "server_notifications", force: :cascade do |t|
    t.text "message"
    t.text "notification_type"
  end

  create_table "server_statistics", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.bigint "reservation_id", null: false
    t.bigint "cpu_usage"
    t.bigint "fps"
    t.bigint "number_of_players"
    t.text "map_name"
    t.bigint "traffic_in"
    t.bigint "traffic_out"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["cpu_usage"], name: "idx_17248_index_server_statistics_on_cpu_usage"
    t.index ["created_at"], name: "idx_17248_index_server_statistics_on_created_at"
    t.index ["fps"], name: "idx_17248_index_server_statistics_on_fps"
    t.index ["number_of_players"], name: "idx_17248_index_server_statistics_on_number_of_players"
    t.index ["reservation_id"], name: "idx_17248_index_server_statistics_on_reservation_id"
    t.index ["server_id"], name: "idx_17248_index_server_statistics_on_server_id"
  end

  create_table "server_uploads", force: :cascade do |t|
    t.integer "server_id"
    t.integer "file_upload_id"
    t.datetime "started_at", precision: nil
    t.datetime "uploaded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_upload_id"], name: "index_server_uploads_on_file_upload_id"
    t.index ["server_id", "file_upload_id"], name: "index_server_uploads_on_server_id_and_file_upload_id", unique: true
    t.index ["server_id"], name: "index_server_uploads_on_server_id"
    t.index ["uploaded_at"], name: "index_server_uploads_on_uploaded_at"
  end

  create_table "servers", force: :cascade do |t|
    t.text "name"
    t.text "path"
    t.text "ip"
    t.text "port"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "rcon"
    t.text "type", default: "LocalServer"
    t.bigint "position", default: 1000
    t.bigint "location_id"
    t.boolean "active", default: true
    t.text "ftp_username"
    t.text "ftp_password"
    t.bigint "ftp_port", default: 21
    t.float "latitude"
    t.float "longitude"
    t.string "billing_id"
    t.string "tv_port"
    t.boolean "sdr", default: false
    t.string "last_sdr_ip"
    t.string "last_sdr_port"
    t.string "last_sdr_tv_port"
    t.integer "last_known_version"
    t.datetime "update_started_at"
    t.string "update_status"
    t.string "resolved_ip"
    t.integer "reservations_count", default: 0, null: false
    t.index ["active"], name: "idx_17217_index_servers_on_active"
    t.index ["ip"], name: "index_servers_on_ip"
    t.index ["latitude", "longitude"], name: "idx_17217_index_servers_on_latitude_and_longitude"
    t.index ["location_id"], name: "idx_17217_index_servers_on_location_id"
    t.index ["reservations_count"], name: "index_servers_on_reservations_count"
    t.index ["resolved_ip"], name: "index_servers_on_resolved_ip"
    t.index ["type"], name: "index_servers_on_type"
  end

  create_table "stac_detections", force: :cascade do |t|
    t.bigint "stac_log_id", null: false
    t.bigint "reservation_player_id", null: false
    t.string "steam_uid", null: false
    t.integer "triggerbot_count", default: 0, null: false
    t.integer "silentaim_count", default: 0, null: false
    t.integer "aimsnap_count", default: 0, null: false
    t.integer "cmdnum_spike_count", default: 0, null: false
    t.integer "other_detection_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_player_id"], name: "index_stac_detections_on_reservation_player_id"
    t.index ["stac_log_id", "steam_uid"], name: "index_stac_detections_on_stac_log_id_and_steam_uid", unique: true
    t.index ["stac_log_id"], name: "index_stac_detections_on_stac_log_id"
    t.index ["steam_uid"], name: "index_stac_detections_on_steam_uid"
  end

  create_table "stac_logs", force: :cascade do |t|
    t.integer "reservation_id"
    t.string "filename"
    t.integer "filesize"
    t.binary "contents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_id"], name: "index_stac_logs_on_reservation_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "uid"
    t.text "provider"
    t.text "name"
    t.text "nickname"
    t.text "email"
    t.text "encrypted_password", default: "", null: false
    t.text "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.bigint "sign_in_count", default: 0
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.text "current_sign_in_ip"
    t.text "last_sign_in_ip"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "logs_tf_api_key"
    t.text "remember_token"
    t.text "time_zone"
    t.text "api_key"
    t.float "latitude"
    t.float "longitude"
    t.bigint "expired_reservations", default: 0
    t.string "demos_tf_api_key"
    t.integer "reservations_count", default: 0, null: false
    t.bigint "total_reservation_seconds", default: 0, null: false
    t.index ["api_key"], name: "idx_17257_index_users_on_api_key", unique: true
    t.index ["latitude", "longitude"], name: "idx_17257_index_users_on_latitude_and_longitude"
    t.index ["reservations_count"], name: "index_users_on_reservations_count"
    t.index ["reset_password_token"], name: "idx_17257_index_users_on_reset_password_token", unique: true
    t.index ["total_reservation_seconds"], name: "index_users_on_total_reservation_seconds"
    t.index ["uid"], name: "idx_17257_index_users_on_uid"
  end

  create_table "vouchers", id: :serial, force: :cascade do |t|
    t.string "code"
    t.integer "product_id"
    t.datetime "claimed_at", precision: nil
    t.integer "claimed_by_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "created_by_id"
    t.integer "order_id"
    t.index ["claimed_by_id"], name: "index_vouchers_on_claimed_by_id"
    t.index ["code"], name: "index_vouchers_on_code"
    t.index ["product_id"], name: "index_vouchers_on_product_id"
  end

  create_table "whitelist_tfs", id: :serial, force: :cascade do |t|
    t.string "tf_whitelist_id"
    t.text "content"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["tf_whitelist_id"], name: "index_whitelist_tfs_on_tf_whitelist_id"
  end

  create_table "whitelists", force: :cascade do |t|
    t.text "file"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "hidden", default: false
    t.index ["hidden"], name: "index_whitelists_on_hidden"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "file_upload_permissions", "users"
  add_foreign_key "stac_detections", "reservation_players"
  add_foreign_key "stac_detections", "stac_logs"
end
