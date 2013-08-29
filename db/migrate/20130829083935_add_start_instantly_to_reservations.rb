class AddStartInstantlyToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :start_instantly, :boolean, :default => false
  end
end
