class AddEndInstantlyToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :end_instantly, :boolean
  end
end
