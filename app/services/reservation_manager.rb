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

  def after_start_reservation_steps
    reservation.provisioned = true
    reservation.save(:validate => false)
  end

  def after_end_reservation_steps
    reservation.ends_at  = Time.current
    reservation.ended    = true
    reservation.save(:validate => false)
  end

  def manage_reservation(action)
    begin
      server.send("#{action}_reservation", reservation)
    rescue Exception => exception
      Rails.logger.error "Something went wrong #{action}ing the server for reservation #{reservation.id} - #{exception}"
      Raven.capture_exception(exception) if Rails.env.production?
    ensure
      send("after_#{action}_reservation_steps")
      Rails.logger.info "[#{Time.now}] #{action.capitalize}ed reservation: #{reservation.id} #{reservation}"
    end
  end
end

