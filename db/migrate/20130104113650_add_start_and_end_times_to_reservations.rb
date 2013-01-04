class AddStartAndEndTimesToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :starts_at, :datetime
    add_column :reservations, :ends_at,   :datetime
  end
end
