# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160902141018) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ar_internal_metadata", primary_key: "key", force: :cascade do |t|
    t.string   "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "group_servers", id: :bigserial, force: :cascade do |t|
    t.integer  "server_id",  limit: 8
    t.integer  "group_id",   limit: 8
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "group_servers", ["group_id"], name: "idx_17095_index_group_servers_on_group_id", using: :btree
  add_index "group_servers", ["server_id"], name: "idx_17095_index_group_servers_on_server_id", using: :btree

  create_table "group_users", id: :bigserial, force: :cascade do |t|
    t.integer  "user_id",    limit: 8
    t.integer  "group_id",   limit: 8
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.datetime "expires_at"
  end

  add_index "group_users", ["expires_at"], name: "idx_17101_index_group_users_on_expires_at", using: :btree
  add_index "group_users", ["group_id"], name: "idx_17101_index_group_users_on_group_id", using: :btree
  add_index "group_users", ["user_id"], name: "idx_17101_index_group_users_on_user_id", using: :btree

  create_table "groups", id: :bigserial, force: :cascade do |t|
    t.text     "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "groups", ["name"], name: "idx_17086_index_groups_on_name", using: :btree

  create_table "hiperz_server_informations", id: :bigserial, force: :cascade do |t|
    t.integer "server_id", limit: 8
    t.integer "hiperz_id", limit: 8
  end

  add_index "hiperz_server_informations", ["hiperz_id"], name: "idx_17107_index_hiperz_server_informations_on_hiperz_id", using: :btree
  add_index "hiperz_server_informations", ["server_id"], name: "idx_17107_index_hiperz_server_informations_on_server_id", using: :btree

  create_table "locations", id: :bigserial, force: :cascade do |t|
    t.text     "name"
    t.text     "flag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "log_uploads", id: :bigserial, force: :cascade do |t|
    t.integer  "reservation_id", limit: 8
    t.text     "file_name"
    t.text     "title"
    t.text     "map_name"
    t.text     "status"
    t.text     "url"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "log_uploads", ["reservation_id"], name: "idx_17122_index_log_uploads_on_reservation_id", using: :btree

  create_table "map_uploads", id: :bigserial, force: :cascade do |t|
    t.text     "name"
    t.text     "file"
    t.integer  "user_id",    limit: 8, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "paypal_orders", id: :bigserial, force: :cascade do |t|
    t.integer  "user_id",    limit: 8
    t.integer  "product_id", limit: 8
    t.text     "payment_id"
    t.text     "payer_id"
    t.text     "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "gift",                 default: false
  end

  add_index "paypal_orders", ["payer_id"], name: "idx_17140_index_paypal_orders_on_payer_id", using: :btree
  add_index "paypal_orders", ["payment_id"], name: "idx_17140_index_paypal_orders_on_payment_id", using: :btree
  add_index "paypal_orders", ["product_id"], name: "idx_17140_index_paypal_orders_on_product_id", using: :btree
  add_index "paypal_orders", ["user_id"], name: "idx_17140_index_paypal_orders_on_user_id", using: :btree

  create_table "player_statistics", id: :bigserial, force: :cascade do |t|
    t.integer  "ping",                  limit: 8
    t.integer  "loss",                  limit: 8
    t.integer  "minutes_connected",     limit: 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reservation_player_id", limit: 8
  end

  add_index "player_statistics", ["created_at"], name: "idx_17149_index_player_statistics_on_created_at", using: :btree
  add_index "player_statistics", ["loss"], name: "idx_17149_index_player_statistics_on_loss", using: :btree
  add_index "player_statistics", ["ping"], name: "idx_17149_index_player_statistics_on_ping", using: :btree
  add_index "player_statistics", ["reservation_player_id"], name: "idx_17149_index_player_statistics_on_reservation_player_id", using: :btree

  create_table "products", id: :bigserial, force: :cascade do |t|
    t.text    "name"
    t.decimal "price",                           precision: 15, scale: 6,                null: false
    t.integer "days",                  limit: 8
    t.boolean "active",                                                   default: true
    t.text    "currency"
    t.boolean "grants_private_server"
  end

  add_index "products", ["grants_private_server"], name: "idx_17155_index_products_on_grants_private_server", using: :btree

  create_table "reservation_players", id: :bigserial, force: :cascade do |t|
    t.integer "reservation_id", limit: 8
    t.text    "steam_uid"
    t.text    "name"
    t.text    "ip"
    t.float   "latitude"
    t.float   "longitude"
  end

  add_index "reservation_players", ["ip"], name: "index_reservation_players_on_ip", using: :btree
  add_index "reservation_players", ["latitude", "longitude"], name: "idx_17193_index_reservation_players_on_latitude_and_longitude", using: :btree
  add_index "reservation_players", ["reservation_id"], name: "idx_17193_index_reservation_players_on_reservation_id", using: :btree
  add_index "reservation_players", ["steam_uid"], name: "idx_17193_index_reservation_players_on_steam_uid", using: :btree

  create_table "reservation_statuses", id: :bigserial, force: :cascade do |t|
    t.integer  "reservation_id", limit: 8
    t.text     "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "reservation_statuses", ["created_at"], name: "idx_17202_index_reservation_statuses_on_created_at", using: :btree
  add_index "reservation_statuses", ["reservation_id"], name: "idx_17202_index_reservation_statuses_on_reservation_id", using: :btree

  create_table "reservations", id: :bigserial, force: :cascade do |t|
    t.integer  "user_id",                 limit: 8
    t.integer  "server_id",               limit: 8
    t.text     "password"
    t.text     "rcon"
    t.text     "tv_password"
    t.text     "tv_relaypassword"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean  "provisioned",                       default: false
    t.boolean  "ended",                             default: false
    t.integer  "server_config_id",        limit: 8
    t.integer  "whitelist_id",            limit: 8
    t.integer  "inactive_minute_counter", limit: 8, default: 0
    t.integer  "last_number_of_players",  limit: 8, default: 0
    t.text     "first_map"
    t.boolean  "start_instantly",                   default: false
    t.boolean  "end_instantly",                     default: false
    t.string   "custom_whitelist_id"
    t.integer  "duration",                limit: 8
    t.boolean  "auto_end",                          default: true
    t.text     "logsecret"
    t.boolean  "enable_plugins",                    default: false
    t.boolean  "enable_arena_respawn",              default: false
    t.boolean  "enable_demos_tf",                   default: false
  end

  add_index "reservations", ["auto_end"], name: "idx_17175_index_reservations_on_auto_end", using: :btree
  add_index "reservations", ["custom_whitelist_id"], name: "idx_17175_index_reservations_on_custom_whitelist_id", using: :btree
  add_index "reservations", ["end_instantly"], name: "idx_17175_index_reservations_on_end_instantly", using: :btree
  add_index "reservations", ["ends_at"], name: "idx_17175_index_reservations_on_ends_at", using: :btree
  add_index "reservations", ["logsecret"], name: "idx_17175_index_reservations_on_logsecret", using: :btree
  add_index "reservations", ["server_config_id"], name: "idx_17175_index_reservations_on_server_config_id", using: :btree
  add_index "reservations", ["server_id", "starts_at"], name: "idx_17175_index_reservations_on_server_id_and_starts_at", unique: true, using: :btree
  add_index "reservations", ["server_id"], name: "idx_17175_index_reservations_on_server_id", using: :btree
  add_index "reservations", ["start_instantly"], name: "idx_17175_index_reservations_on_start_instantly", using: :btree
  add_index "reservations", ["starts_at"], name: "idx_17175_index_reservations_on_starts_at", using: :btree
  add_index "reservations", ["updated_at"], name: "idx_17175_index_reservations_on_updated_at", using: :btree
  add_index "reservations", ["user_id"], name: "idx_17175_index_reservations_on_user_id", using: :btree
  add_index "reservations", ["whitelist_id"], name: "idx_17175_index_reservations_on_whitelist_id", using: :btree

  create_table "server_configs", id: :bigserial, force: :cascade do |t|
    t.text     "file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "server_notifications", id: :bigserial, force: :cascade do |t|
    t.text "message"
    t.text "notification_type"
  end

  create_table "server_statistics", id: :bigserial, force: :cascade do |t|
    t.integer  "server_id",         limit: 8, null: false
    t.integer  "reservation_id",    limit: 8, null: false
    t.integer  "cpu_usage",         limit: 8
    t.integer  "fps",               limit: 8
    t.integer  "number_of_players", limit: 8
    t.text     "map_name"
    t.integer  "traffic_in",        limit: 8
    t.integer  "traffic_out",       limit: 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "server_statistics", ["cpu_usage"], name: "idx_17248_index_server_statistics_on_cpu_usage", using: :btree
  add_index "server_statistics", ["created_at"], name: "idx_17248_index_server_statistics_on_created_at", using: :btree
  add_index "server_statistics", ["fps"], name: "idx_17248_index_server_statistics_on_fps", using: :btree
  add_index "server_statistics", ["number_of_players"], name: "idx_17248_index_server_statistics_on_number_of_players", using: :btree
  add_index "server_statistics", ["reservation_id"], name: "idx_17248_index_server_statistics_on_reservation_id", using: :btree
  add_index "server_statistics", ["server_id"], name: "idx_17248_index_server_statistics_on_server_id", using: :btree

  create_table "servers", id: :bigserial, force: :cascade do |t|
    t.text     "name"
    t.text     "path"
    t.text     "ip"
    t.text     "port"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "rcon"
    t.text     "type",                   default: "LocalServer"
    t.integer  "position",     limit: 8, default: 1000
    t.integer  "location_id",  limit: 8
    t.boolean  "active",                 default: true
    t.text     "ftp_username"
    t.text     "ftp_password"
    t.integer  "ftp_port",     limit: 8, default: 21
    t.float    "latitude"
    t.float    "longitude"
    t.string   "billing_id"
  end

  add_index "servers", ["active"], name: "idx_17217_index_servers_on_active", using: :btree
  add_index "servers", ["latitude", "longitude"], name: "idx_17217_index_servers_on_latitude_and_longitude", using: :btree
  add_index "servers", ["location_id"], name: "idx_17217_index_servers_on_location_id", using: :btree

  create_table "users", id: :bigserial, force: :cascade do |t|
    t.text     "uid"
    t.text     "provider"
    t.text     "name"
    t.text     "nickname"
    t.text     "email"
    t.text     "encrypted_password",               default: "", null: false
    t.text     "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          limit: 8, default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.text     "current_sign_in_ip"
    t.text     "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "logs_tf_api_key"
    t.text     "remember_token"
    t.text     "time_zone"
    t.text     "api_key"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "expired_reservations",   limit: 8, default: 0
  end

  add_index "users", ["api_key"], name: "idx_17257_index_users_on_api_key", unique: true, using: :btree
  add_index "users", ["latitude", "longitude"], name: "idx_17257_index_users_on_latitude_and_longitude", using: :btree
  add_index "users", ["reset_password_token"], name: "idx_17257_index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["uid"], name: "idx_17257_index_users_on_uid", using: :btree

  create_table "vouchers", force: :cascade do |t|
    t.string   "code"
    t.integer  "product_id"
    t.datetime "claimed_at"
    t.integer  "claimed_by_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "created_by_id"
    t.integer  "paypal_order_id"
  end

  add_index "vouchers", ["claimed_by_id"], name: "index_vouchers_on_claimed_by_id", using: :btree
  add_index "vouchers", ["code"], name: "index_vouchers_on_code", using: :btree
  add_index "vouchers", ["product_id"], name: "index_vouchers_on_product_id", using: :btree

  create_table "whitelists", id: :bigserial, force: :cascade do |t|
    t.text     "file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
