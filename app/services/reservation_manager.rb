class ReservationManager

  attr_reader :reservation
  delegate :server, :to => :reservation, :prefix => false

  def initialize(reservation)
    @reservation = reservation
  end

  def start_reservation
    manage_reservation(:start)
  end

  def end_reservation
    manage_reservation(:end) unless reservation.ended?
  end

  def update_reservation
    manage_reservation(:update)
  end

  def after_start_reservation_steps
    reservation.provisioned = true
    reservation.save(:validate => false)
  end

  def after_update_reservation_steps
    reservation.inactive_minute_counter = 0
    reservation.save(:validate => false)
  end

  def after_end_reservation_steps
    reservation.ends_at  = Time.current
    reservation.ended    = true
    reservation.duration = reservation.ends_at.to_i - reservation.starts_at.to_i
    reservation.save(:validate => false)
  end

  def manage_reservation(action)
    begin
      server.send("#{action}_reservation", reservation)
    rescue Exception => exception
      Rails.logger.error "Something went wrong #{action}-ing the server for reservation #{reservation.id} - #{exception}"
      Raven.capture_exception(exception) if Rails.env.production?
    ensure
      send("after_#{action}_reservation_steps")
      Rails.logger.info "[#{Time.now}] #{action.capitalize}ed reservation: #{reservation.id} #{reservation}"
    end
  end
end

