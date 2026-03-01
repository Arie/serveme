# typed: true

class CreateStacDetections < ActiveRecord::Migration[8.1]
  def change
    create_table :stac_detections do |t|
      t.integer :reservation_id, null: false
      t.bigint :steam_uid, null: false
      t.string :player_name, null: false
      t.string :steam_id
      t.string :detection_type, null: false
      t.integer :count, null: false, default: 1
      t.integer :stac_log_id

      t.timestamps
    end

    add_index :stac_detections, :steam_uid
    add_index :stac_detections, :reservation_id
  end
end
