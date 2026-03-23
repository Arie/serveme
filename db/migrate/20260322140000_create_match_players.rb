# frozen_string_literal: true

class CreateMatchPlayers < ActiveRecord::Migration[7.2]
  def change
    create_table :reservation_matches do |t|
      t.references :reservation, null: false, index: true
      t.integer :red_score
      t.integer :blue_score
      t.float :total_duration_seconds, default: 0, null: false
      t.integer :match_number, default: 1, null: false
      t.timestamps
    end

    create_table :match_players do |t|
      t.references :reservation_match, null: false, index: true
      t.bigint :steam_uid, null: false
      t.string :team, null: false
      t.string :tf2_class, null: false
      t.integer :kills, default: 0, null: false
      t.integer :deaths, default: 0, null: false
      t.integer :assists, default: 0, null: false
      t.integer :damage, default: 0, null: false
      t.integer :damage_taken, default: 0, null: false
      t.integer :healing, default: 0, null: false
      t.integer :heals_received, default: 0, null: false
      t.integer :ubers, default: 0, null: false
      t.integer :drops, default: 0, null: false
      t.integer :airshots, default: 0, null: false
      t.integer :caps, default: 0, null: false
      t.boolean :won, null: false
      t.timestamps
    end

    add_index :match_players, [ :reservation_match_id, :steam_uid ], unique: true
    add_index :match_players, :steam_uid
  end
end
