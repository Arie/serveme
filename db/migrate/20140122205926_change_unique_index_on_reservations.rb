class ChangeUniqueIndexOnReservations < ActiveRecord::Migration
  def change
    remove_index :reservations, [:user_id, :starts_at]
    add_index :reservations, [:server_id, :starts_at], :unique => true
  end
end
