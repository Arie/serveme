class AddEndedBooleanToReservations < ActiveRecord::Migration
  def change
    add_column :reservations, :ended, :boolean, :default => false
    Reservation.where('ends_at < ?', Time.now).update_all(:ended => true)
  end
end
