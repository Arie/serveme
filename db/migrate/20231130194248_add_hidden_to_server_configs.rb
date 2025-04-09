# typed: true

class AddHiddenToServerConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :server_configs, :hidden, :boolean, default: false
    add_index :server_configs, :hidden
  end
end
