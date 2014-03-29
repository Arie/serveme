class AddLogsecretToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :logsecret, :string, :limit => 64
    add_index :reservations, :logsecret
  end
end
