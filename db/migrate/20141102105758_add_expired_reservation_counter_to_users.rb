class AddExpiredReservationCounterToUsers < ActiveRecord::Migration
  def change
    add_column :users, :expired_reservations, :integer, :default => 0
  end
end
