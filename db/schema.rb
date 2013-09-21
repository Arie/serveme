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

ActiveRecord::Schema.define(version: 20130921134940) do

  create_table "group_servers", force: true do |t|
    t.integer  "server_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "group_servers", ["group_id"], name: "index_group_servers_on_group_id", using: :btree
  add_index "group_servers", ["server_id"], name: "index_group_servers_on_server_id", using: :btree

  create_table "group_users", force: true do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "group_users", ["group_id"], name: "index_group_users_on_group_id", using: :btree
  add_index "group_users", ["user_id"], name: "index_group_users_on_user_id", using: :btree

  create_table "groups", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "groups", ["name"], name: "index_groups_on_name", using: :btree

  create_table "locations", force: true do |t|
    t.string   "name"
    t.string   "flag"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "log_uploads", force: true do |t|
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

  create_table "reservations", force: true do |t|
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
    t.boolean  "provisioned",             default: false
    t.boolean  "ended",                   default: false
    t.integer  "server_config_id"
    t.integer  "whitelist_id"
    t.integer  "inactive_minute_counter", default: 0
    t.boolean  "disable_source_tv",       default: false
    t.integer  "last_number_of_players",  default: 0
    t.string   "first_map"
    t.boolean  "start_instantly",         default: false
    t.boolean  "end_instantly",           default: false
    t.integer  "custom_whitelist_id"
  end

  add_index "reservations", ["custom_whitelist_id"], name: "index_reservations_on_custom_whitelist_id", using: :btree
  add_index "reservations", ["end_instantly"], name: "index_reservations_on_end_instantly", using: :btree
  add_index "reservations", ["ends_at"], name: "index_reservations_on_ends_at", using: :btree
  add_index "reservations", ["server_config_id"], name: "index_reservations_on_server_config_id", using: :btree
  add_index "reservations", ["server_id"], name: "index_reservations_on_server_id", using: :btree
  add_index "reservations", ["start_instantly"], name: "index_reservations_on_start_instantly", using: :btree
  add_index "reservations", ["starts_at"], name: "index_reservations_on_starts_at", using: :btree
  add_index "reservations", ["updated_at"], name: "index_reservations_on_updated_at", using: :btree
  add_index "reservations", ["user_id", "starts_at"], name: "index_reservations_on_user_id_and_starts_at", unique: true, using: :btree
  add_index "reservations", ["user_id"], name: "index_reservations_on_user_id", using: :btree
  add_index "reservations", ["whitelist_id"], name: "index_reservations_on_whitelist_id", using: :btree

  create_table "server_configs", force: true do |t|
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "servers", force: true do |t|
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
  end

  add_index "servers", ["active"], name: "index_servers_on_active", using: :btree
  add_index "servers", ["location_id"], name: "index_servers_on_location_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "uid"
    t.string   "provider"
    t.string   "name"
    t.string   "nickname"
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "logs_tf_api_key"
    t.string   "remember_token"
    t.string   "time_zone"
  end

  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["uid"], name: "index_users_on_uid", using: :btree

  create_table "versions", force: true do |t|
    t.string   "item_type",  null: false
    t.integer  "item_id",    null: false
    t.string   "event",      null: false
    t.string   "whodunnit"
    t.text     "object"
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree

  create_table "whitelist_tfs", force: true do |t|
    t.integer  "tf_whitelist_id"
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "whitelist_tfs", ["tf_whitelist_id"], name: "index_whitelist_tfs_on_tf_whitelist_id", using: :btree

  create_table "whitelists", force: true do |t|
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
