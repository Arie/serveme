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

ActiveRecord::Schema.define(version: 20170504201746) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "group_servers", force: :cascade do |t|
    t.integer  "server_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id"], name: "idx_17095_index_group_servers_on_group_id", using: :btree
    t.index ["group_id"], name: "index_group_servers_on_group_id", using: :btree
    t.index ["server_id"], name: "idx_17095_index_group_servers_on_server_id", using: :btree
    t.index ["server_id"], name: "index_group_servers_on_server_id", using: :btree
  end

  create_table "group_users", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "expires_at"
    t.index ["expires_at"], name: "idx_17101_index_group_users_on_expires_at", using: :btree
    t.index ["expires_at"], name: "index_group_users_on_expires_at", using: :btree
    t.index ["group_id"], name: "idx_17101_index_group_users_on_group_id", using: :btree
    t.index ["group_id"], name: "index_group_users_on_group_id", using: :btree
    t.index ["user_id"], name: "idx_17101_index_group_users_on_user_id", using: :btree
    t.index ["user_id"], name: "index_group_users_on_user_id", using: :btree
  end

  create_table "groups", force: :cascade do |t|
    t.string   "name",       limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "idx_17086_index_groups_on_name", using: :btree
    t.index ["name"], name: "index_groups_on_name", using: :btree
  end

  create_table "hiperz_server_informations", force: :cascade do |t|
    t.integer "server_id"
    t.integer "hiperz_id"
    t.index ["hiperz_id"], name: "idx_17107_index_hiperz_server_informations_on_hiperz_id", using: :btree
    t.index ["hiperz_id"], name: "index_hiperz_server_informations_on_hiperz_id", using: :btree
    t.index ["server_id"], name: "idx_17107_index_hiperz_server_informations_on_server_id", using: :btree
    t.index ["server_id"], name: "index_hiperz_server_informations_on_server_id", using: :btree
  end

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
    t.index ["reservation_id"], name: "idx_17122_index_log_uploads_on_reservation_id", using: :btree
    t.index ["reservation_id"], name: "index_log_uploads_on_reservation_id", using: :btree
  end

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
    t.string   "type"
    t.index ["payer_id"], name: "idx_17140_index_paypal_orders_on_payer_id", using: :btree
    t.index ["payer_id"], name: "index_orders_on_payer_id", using: :btree
    t.index ["payment_id"], name: "idx_17140_index_paypal_orders_on_payment_id", using: :btree
    t.index ["payment_id"], name: "index_orders_on_payment_id", using: :btree
    t.index ["product_id"], name: "idx_17140_index_paypal_orders_on_product_id", using: :btree
    t.index ["product_id"], name: "index_orders_on_product_id", using: :btree
    t.index ["user_id"], name: "idx_17140_index_paypal_orders_on_user_id", using: :btree
    t.index ["user_id"], name: "index_orders_on_user_id", using: :btree
  end

  create_table "player_statistics", force: :cascade do |t|
    t.integer  "ping"
    t.integer  "loss"
    t.integer  "minutes_connected"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reservation_player_id"
    t.index ["created_at"], name: "idx_17149_index_player_statistics_on_created_at", using: :btree
    t.index ["created_at"], name: "index_player_statistics_on_created_at", using: :btree
    t.index ["loss"], name: "idx_17149_index_player_statistics_on_loss", using: :btree
    t.index ["loss"], name: "index_player_statistics_on_loss", using: :btree
    t.index ["ping"], name: "idx_17149_index_player_statistics_on_ping", using: :btree
    t.index ["ping"], name: "index_player_statistics_on_ping", using: :btree
    t.index ["reservation_player_id"], name: "idx_17149_index_player_statistics_on_reservation_player_id", using: :btree
    t.index ["reservation_player_id"], name: "index_player_statistics_on_reservation_player_id", using: :btree
  end

  create_table "products", force: :cascade do |t|
    t.string  "name"
    t.decimal "price",                 precision: 15, scale: 6,                null: false
    t.integer "days"
    t.boolean "active",                                         default: true
    t.string  "currency"
    t.boolean "grants_private_server"
    t.index ["grants_private_server"], name: "idx_17155_index_products_on_grants_private_server", using: :btree
    t.index ["grants_private_server"], name: "index_products_on_grants_private_server", using: :btree
  end

  create_table "reservation_players", force: :cascade do |t|
    t.integer "reservation_id"
    t.string  "steam_uid",      limit: 191
    t.string  "name",           limit: 191
    t.string  "ip",             limit: 191
    t.float   "latitude"
    t.float   "longitude"
    t.index ["ip"], name: "index_reservation_players_on_ip", using: :btree
    t.index ["latitude", "longitude"], name: "idx_17193_index_reservation_players_on_latitude_and_longitude", using: :btree
    t.index ["latitude", "longitude"], name: "index_reservation_players_on_latitude_and_longitude", using: :btree
    t.index ["reservation_id"], name: "idx_17193_index_reservation_players_on_reservation_id", using: :btree
    t.index ["reservation_id"], name: "index_reservation_players_on_reservation_id", using: :btree
    t.index ["steam_uid"], name: "idx_17193_index_reservation_players_on_steam_uid", using: :btree
    t.index ["steam_uid"], name: "index_reservation_players_on_steam_uid", using: :btree
  end

  create_table "reservation_statuses", force: :cascade do |t|
    t.integer  "reservation_id"
    t.string   "status",         limit: 191
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["created_at"], name: "idx_17202_index_reservation_statuses_on_created_at", using: :btree
    t.index ["created_at"], name: "index_reservation_statuses_on_created_at", using: :btree
    t.index ["reservation_id"], name: "idx_17202_index_reservation_statuses_on_reservation_id", using: :btree
    t.index ["reservation_id"], name: "index_reservation_statuses_on_reservation_id", using: :btree
  end

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
    t.boolean  "enable_demos_tf",                    default: false
    t.index ["auto_end"], name: "idx_17175_index_reservations_on_auto_end", using: :btree
    t.index ["auto_end"], name: "index_reservations_on_auto_end", using: :btree
    t.index ["custom_whitelist_id"], name: "idx_17175_index_reservations_on_custom_whitelist_id", using: :btree
    t.index ["custom_whitelist_id"], name: "index_reservations_on_custom_whitelist_id", using: :btree
    t.index ["end_instantly"], name: "idx_17175_index_reservations_on_end_instantly", using: :btree
    t.index ["end_instantly"], name: "index_reservations_on_end_instantly", using: :btree
    t.index ["ends_at"], name: "idx_17175_index_reservations_on_ends_at", using: :btree
    t.index ["ends_at"], name: "index_reservations_on_ends_at", using: :btree
    t.index ["logsecret"], name: "idx_17175_index_reservations_on_logsecret", using: :btree
    t.index ["logsecret"], name: "index_reservations_on_logsecret", using: :btree
    t.index ["server_config_id"], name: "idx_17175_index_reservations_on_server_config_id", using: :btree
    t.index ["server_config_id"], name: "index_reservations_on_server_config_id", using: :btree
    t.index ["server_id", "starts_at"], name: "idx_17175_index_reservations_on_server_id_and_starts_at", unique: true, using: :btree
    t.index ["server_id", "starts_at"], name: "index_reservations_on_server_id_and_starts_at", unique: true, using: :btree
    t.index ["server_id"], name: "idx_17175_index_reservations_on_server_id", using: :btree
    t.index ["server_id"], name: "index_reservations_on_server_id", using: :btree
    t.index ["start_instantly"], name: "idx_17175_index_reservations_on_start_instantly", using: :btree
    t.index ["start_instantly"], name: "index_reservations_on_start_instantly", using: :btree
    t.index ["starts_at"], name: "idx_17175_index_reservations_on_starts_at", using: :btree
    t.index ["starts_at"], name: "index_reservations_on_starts_at", using: :btree
    t.index ["updated_at"], name: "idx_17175_index_reservations_on_updated_at", using: :btree
    t.index ["updated_at"], name: "index_reservations_on_updated_at", using: :btree
    t.index ["user_id"], name: "idx_17175_index_reservations_on_user_id", using: :btree
    t.index ["user_id"], name: "index_reservations_on_user_id", using: :btree
    t.index ["whitelist_id"], name: "idx_17175_index_reservations_on_whitelist_id", using: :btree
    t.index ["whitelist_id"], name: "index_reservations_on_whitelist_id", using: :btree
  end

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
    t.index ["cpu_usage"], name: "idx_17248_index_server_statistics_on_cpu_usage", using: :btree
    t.index ["cpu_usage"], name: "index_server_statistics_on_cpu_usage", using: :btree
    t.index ["created_at"], name: "idx_17248_index_server_statistics_on_created_at", using: :btree
    t.index ["created_at"], name: "index_server_statistics_on_created_at", using: :btree
    t.index ["fps"], name: "idx_17248_index_server_statistics_on_fps", using: :btree
    t.index ["fps"], name: "index_server_statistics_on_fps", using: :btree
    t.index ["number_of_players"], name: "idx_17248_index_server_statistics_on_number_of_players", using: :btree
    t.index ["number_of_players"], name: "index_server_statistics_on_number_of_players", using: :btree
    t.index ["reservation_id"], name: "idx_17248_index_server_statistics_on_reservation_id", using: :btree
    t.index ["reservation_id"], name: "index_server_statistics_on_reservation_id", using: :btree
    t.index ["server_id"], name: "idx_17248_index_server_statistics_on_server_id", using: :btree
    t.index ["server_id"], name: "index_server_statistics_on_server_id", using: :btree
  end

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
    t.index ["active"], name: "idx_17217_index_servers_on_active", using: :btree
    t.index ["active"], name: "index_servers_on_active", using: :btree
    t.index ["latitude", "longitude"], name: "idx_17217_index_servers_on_latitude_and_longitude", using: :btree
    t.index ["latitude", "longitude"], name: "index_servers_on_latitude_and_longitude", using: :btree
    t.index ["location_id"], name: "idx_17217_index_servers_on_location_id", using: :btree
    t.index ["location_id"], name: "index_servers_on_location_id", using: :btree
  end

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
    t.string   "demos_tf_api_key"
    t.index ["api_key"], name: "idx_17257_index_users_on_api_key", unique: true, using: :btree
    t.index ["api_key"], name: "index_users_on_api_key", unique: true, using: :btree
    t.index ["latitude", "longitude"], name: "idx_17257_index_users_on_latitude_and_longitude", using: :btree
    t.index ["latitude", "longitude"], name: "index_users_on_latitude_and_longitude", using: :btree
    t.index ["reset_password_token"], name: "idx_17257_index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["uid"], name: "idx_17257_index_users_on_uid", using: :btree
    t.index ["uid"], name: "index_users_on_uid", using: :btree
  end

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",  limit: 191, null: false
    t.integer  "item_id",                null: false
    t.string   "event",      limit: 191, null: false
    t.string   "whodunnit",  limit: 191
    t.text     "object"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree
  end

  create_table "vouchers", force: :cascade do |t|
    t.string   "code"
    t.integer  "product_id"
    t.datetime "claimed_at"
    t.integer  "claimed_by_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "created_by_id"
    t.integer  "order_id"
    t.index ["claimed_by_id"], name: "index_vouchers_on_claimed_by_id", using: :btree
    t.index ["code"], name: "index_vouchers_on_code", using: :btree
    t.index ["product_id"], name: "index_vouchers_on_product_id", using: :btree
  end

  create_table "whitelist_tfs", force: :cascade do |t|
    t.string   "tf_whitelist_id"
    t.text     "content"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.index ["tf_whitelist_id"], name: "index_whitelist_tfs_on_tf_whitelist_id", using: :btree
  end

  create_table "whitelists", force: :cascade do |t|
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
