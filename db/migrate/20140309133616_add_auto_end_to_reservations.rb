class AddAutoEndToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :auto_end, :boolean, :default => true
    add_index :reservations, :auto_end
  end
end
