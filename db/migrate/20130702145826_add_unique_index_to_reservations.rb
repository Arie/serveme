class AddUniqueIndexToReservations < ActiveRecord::Migration
  def change
    add_index :reservations, [:user_id, :starts_at], :unique => true
  end
end
