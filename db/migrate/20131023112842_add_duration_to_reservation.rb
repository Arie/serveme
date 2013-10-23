class AddDurationToReservation < ActiveRecord::Migration

  class Reservation < ActiveRecord::Base
  end

  def change
    add_column :reservations, :duration, :integer
    Reservation.reset_column_information
    Reservation.all.each do |reservation|
      duration = (reservation.ends_at - reservation.starts_at).to_i
      reservation.update_column(:duration, duration)
    end
  end

end
