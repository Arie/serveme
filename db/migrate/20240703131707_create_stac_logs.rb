# typed: true

class CreateStacLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :stac_logs do |t|
      t.integer :reservation_id
      t.string :filename
      t.integer :filesize
      t.binary :contents

      t.timestamps
    end

    add_index :stac_logs, :reservation_id
  end
end
