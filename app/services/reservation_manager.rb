class ReservationManager

  attr_reader :reservation
  delegate :server, :to => :reservation, :prefix => false

  def initialize(reservation)
    @reservation = reservation
  end

  def start_reservation
    reservation.reservation_statuses.create!(:status => "Starting")
    manage_reservation(:start)
  end

  def end_reservation
    reservation.reservation_statuses.create!(:status => "Ending")
    puts reservation.inspect
    puts reservation.ended
    puts reservation.ended?
    manage_reservation(:end) unless reservation.ended?
  end

  def update_reservation
    manage_reservation(:update)
  end

  def manage_reservation(action)
    ReservationWorker.perform_async(reservation.id, action.to_s)
  end
end

