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

ActiveRecord::Schema.define(version: 20151015103512) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "group_servers", force: :cascade do |t|
    t.integer  "server_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "group_servers", ["group_id"], name: "index_group_servers_on_group_id", using: :btree
  add_index "group_servers", ["server_id"], name: "index_group_servers_on_server_id", using: :btree

  create_table "group_users", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "expires_at"
  end

  add_index "group_users", ["expires_at"], name: "index_group_users_on_expires_at", using: :btree
  add_index "group_users", ["group_id"], name: "index_group_users_on_group_id", using: :btree
  add_index "group_users", ["user_id"], name: "index_group_users_on_user_id", using: :btree

  create_table "groups", force: :cascade do |t|
    t.string   "name",       limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "groups", ["name"], name: "index_groups_on_name", using: :btree

  create_table "hiperz_server_informations", force: :cascade do |t|
    t.integer "server_id"
    t.integer "hiperz_id"
  end

  add_index "hiperz_server_informations", ["hiperz_id"], name: "index_hiperz_server_informations_on_hiperz_id", using: :btree
  add_index "hiperz_server_informations", ["server_id"], name: "index_hiperz_server_informations_on_server_id", using: :btree

  create_table "locations", force: :cascade do |t|
    t.string   "name"
    t.string   "flag"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "log_uploads", force: :cascade do |t|
    t.integer  "reservation_id"
    t.string   "file_name"
    t.string   "title"
    t.string   "map_name"
    t.text     "status"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "log_uploads", ["reservation_id"], name: "index_log_uploads_on_reservation_id", using: :btree

  create_table "map_uploads", force: :cascade do |t|
    t.string   "name"
    t.string   "file"
    t.integer  "user_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "paypal_orders", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "product_id"
    t.string   "payment_id", limit: 191
    t.string   "payer_id",   limit: 191
    t.string   "status",     limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "gift",                   default: false
  end

  add_index "paypal_orders", ["payer_id"], name: "index_paypal_orders_on_payer_id", using: :btree
  add_index "paypal_orders", ["payment_id"], name: "index_paypal_orders_on_payment_id", using: :btree
  add_index "paypal_orders", ["product_id"], name: "index_paypal_orders_on_product_id", using: :btree
  add_index "paypal_orders", ["user_id"], name: "index_paypal_orders_on_user_id", using: :btree

  create_table "player_statistics", force: :cascade do |t|
    t.integer  "ping"
    t.integer  "loss"
    t.integer  "minutes_connected"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reservation_player_id"
  end

  add_index "player_statistics", ["created_at"], name: "index_player_statistics_on_created_at", using: :btree
  add_index "player_statistics", ["loss"], name: "index_player_statistics_on_loss", using: :btree
  add_index "player_statistics", ["ping"], name: "index_player_statistics_on_ping", using: :btree
  add_index "player_statistics", ["reservation_player_id"], name: "index_player_statistics_on_reservation_player_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.string  "name"
    t.decimal "price",                 precision: 15, scale: 6,                null: false
    t.integer "days"
    t.boolean "active",                                         default: true
    t.string  "currency"
    t.boolean "grants_private_server"
  end

  add_index "products", ["grants_private_server"], name: "index_products_on_grants_private_server", using: :btree

  create_table "reservation_players", force: :cascade do |t|
    t.integer "reservation_id"
    t.string  "steam_uid",      limit: 191
    t.string  "name",           limit: 191
    t.string  "ip",             limit: 191
    t.float   "latitude"
    t.float   "longitude"
  end

  add_index "reservation_players", ["latitude", "longitude"], name: "index_reservation_players_on_latitude_and_longitude", using: :btree
  add_index "reservation_players", ["reservation_id"], name: "index_reservation_players_on_reservation_id", using: :btree
  add_index "reservation_players", ["steam_uid"], name: "index_reservation_players_on_steam_uid", using: :btree

  create_table "reservation_statuses", force: :cascade do |t|
    t.integer  "reservation_id"
    t.string   "status",         limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "reservation_statuses", ["created_at"], name: "index_reservation_statuses_on_created_at", using: :btree
  add_index "reservation_statuses", ["reservation_id"], name: "index_reservation_statuses_on_reservation_id", using: :btree

  create_table "reservations", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "server_id"
    t.string   "password"
    t.string   "rcon"
    t.string   "tv_password"
    t.string   "tv_relaypassword"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean  "provisioned",                        default: false
    t.boolean  "ended",                              default: false
    t.integer  "server_config_id"
    t.integer  "whitelist_id"
    t.integer  "inactive_minute_counter",            default: 0
    t.integer  "last_number_of_players",             default: 0
    t.string   "first_map"
    t.boolean  "start_instantly",                    default: false
    t.boolean  "end_instantly",                      default: false
    t.string   "custom_whitelist_id"
    t.integer  "duration"
    t.boolean  "auto_end",                           default: true
    t.string   "logsecret",               limit: 64
    t.boolean  "enable_plugins",                     default: false
    t.boolean  "enable_arena_respawn",               default: false
  end

  add_index "reservations", ["auto_end"], name: "index_reservations_on_auto_end", using: :btree
  add_index "reservations", ["custom_whitelist_id"], name: "index_reservations_on_custom_whitelist_id", using: :btree
  add_index "reservations", ["end_instantly"], name: "index_reservations_on_end_instantly", using: :btree
  add_index "reservations", ["ends_at"], name: "index_reservations_on_ends_at", using: :btree
  add_index "reservations", ["logsecret"], name: "index_reservations_on_logsecret", using: :btree
  add_index "reservations", ["server_config_id"], name: "index_reservations_on_server_config_id", using: :btree
  add_index "reservations", ["server_id", "starts_at"], name: "index_reservations_on_server_id_and_starts_at", unique: true, using: :btree
  add_index "reservations", ["server_id"], name: "index_reservations_on_server_id", using: :btree
  add_index "reservations", ["start_instantly"], name: "index_reservations_on_start_instantly", using: :btree
  add_index "reservations", ["starts_at"], name: "index_reservations_on_starts_at", using: :btree
  add_index "reservations", ["updated_at"], name: "index_reservations_on_updated_at", using: :btree
  add_index "reservations", ["user_id"], name: "index_reservations_on_user_id", using: :btree
  add_index "reservations", ["whitelist_id"], name: "index_reservations_on_whitelist_id", using: :btree

  create_table "server_configs", force: :cascade do |t|
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "server_notifications", force: :cascade do |t|
    t.string "message",           limit: 190
    t.string "notification_type", limit: 191
  end

  create_table "server_statistics", force: :cascade do |t|
    t.integer  "server_id",                     null: false
    t.integer  "reservation_id",                null: false
    t.integer  "cpu_usage"
    t.integer  "fps"
    t.integer  "number_of_players"
    t.string   "map_name",          limit: 191
    t.integer  "traffic_in"
    t.integer  "traffic_out"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "server_statistics", ["cpu_usage"], name: "index_server_statistics_on_cpu_usage", using: :btree
  add_index "server_statistics", ["created_at"], name: "index_server_statistics_on_created_at", using: :btree
  add_index "server_statistics", ["fps"], name: "index_server_statistics_on_fps", using: :btree
  add_index "server_statistics", ["number_of_players"], name: "index_server_statistics_on_number_of_players", using: :btree
  add_index "server_statistics", ["reservation_id"], name: "index_server_statistics_on_reservation_id", using: :btree
  add_index "server_statistics", ["server_id"], name: "index_server_statistics_on_server_id", using: :btree

  create_table "servers", force: :cascade do |t|
    t.string   "name"
    t.string   "path"
    t.string   "ip"
    t.string   "port"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "rcon"
    t.string   "type",         default: "LocalServer"
    t.integer  "position",     default: 1000
    t.integer  "location_id"
    t.boolean  "active",       default: true
    t.string   "ftp_username"
    t.string   "ftp_password"
    t.integer  "ftp_port",     default: 21
    t.float    "latitude"
    t.float    "longitude"
    t.string   "billing_id"
  end

  add_index "servers", ["active"], name: "index_servers_on_active", using: :btree
  add_index "servers", ["latitude", "longitude"], name: "index_servers_on_latitude_and_longitude", using: :btree
  add_index "servers", ["location_id"], name: "index_servers_on_location_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "uid",                    limit: 191
    t.string   "provider",               limit: 191
    t.string   "name",                   limit: 191
    t.string   "nickname",               limit: 191
    t.string   "email",                  limit: 191, default: "", null: false
    t.string   "encrypted_password",     limit: 191, default: "", null: false
    t.string   "reset_password_token",   limit: 191
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 191
    t.string   "last_sign_in_ip",        limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "logs_tf_api_key"
    t.string   "remember_token"
    t.string   "time_zone"
    t.string   "api_key",                limit: 32
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "expired_reservations",               default: 0
  end

  add_index "users", ["api_key"], name: "index_users_on_api_key", unique: true, using: :btree
  add_index "users", ["latitude", "longitude"], name: "index_users_on_latitude_and_longitude", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["uid"], name: "index_users_on_uid", using: :btree

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",  limit: 191, null: false
    t.integer  "item_id",                null: false
    t.string   "event",      limit: 191, null: false
    t.string   "whodunnit",  limit: 191
    t.text     "object"
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree

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

  create_table "whitelists", force: :cascade do |t|
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
