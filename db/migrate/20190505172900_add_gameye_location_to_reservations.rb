class AddGameyeLocationToReservations < ActiveRecord::Migration[5.2]
  def change
    add_column :reservations, :gameye_location, :string
  end
end
