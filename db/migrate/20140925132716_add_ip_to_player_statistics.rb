class AddIpToPlayerStatistics < ActiveRecord::Migration
  def change
    add_column :player_statistics, :ip, :string, :limit => 191
  end
end
