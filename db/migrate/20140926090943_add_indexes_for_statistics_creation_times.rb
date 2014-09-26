class AddIndexesForStatisticsCreationTimes < ActiveRecord::Migration
  def change
    add_index :server_statistics, :created_at
    add_index :player_statistics, :created_at
  end
end
