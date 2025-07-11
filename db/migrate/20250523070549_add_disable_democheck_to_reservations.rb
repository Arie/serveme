# typed: true

class AddDisableDemocheckToReservations < ActiveRecord::Migration[7.0]
  def change
    add_column :reservations, :disable_democheck, :boolean, default: false
  end
end
