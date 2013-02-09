class DropDateColumnFromReservations < ActiveRecord::Migration
  def up
    remove_column :reservations, :date
  end

  def down
    add_column :reservations, :date, :date
  end
end
