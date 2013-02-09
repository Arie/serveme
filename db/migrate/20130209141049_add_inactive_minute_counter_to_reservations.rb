class AddInactiveMinuteCounterToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :inactive_minute_counter, :integer, :default => 0
  end
end
