class AddIndexToReservationUpdatedAt < ActiveRecord::Migration
  def change
    add_index :reservations, :updated_at
  end
end
