class CreateServerConfigs < ActiveRecord::Migration
  def up
    create_table :server_configs do |t|
      t.string :file
      t.timestamps
    end
  end

  def down
    drop_table :server_configs
  end
end
