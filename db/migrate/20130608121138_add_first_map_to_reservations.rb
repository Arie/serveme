class AddFirstMapToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :first_map, :string
  end
end
