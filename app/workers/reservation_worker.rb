# frozen_string_literal: true
class ReservationWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  attr_accessor :reservation, :reservation_id

  def perform(reservation_id, action)
    @reservation_id = reservation_id
    begin
      $lock.synchronize("#{action}-reservation-#{reservation_id}", retries: 1, expiry: 2.minutes) do
        @reservation = Reservation.find(reservation_id)
        server = reservation.server
        server.send("#{action}_reservation", reservation)
      end
    rescue Exception => exception
      Rails.logger.error "Something went wrong #{action}-ing the server for reservation #{reservation_id} - #{exception}"
      Raven.capture_exception(exception) if Rails.env.production?
    ensure
      send("after_#{action}_reservation_steps") if reservation
      Rails.logger.info "#{action.capitalize}ed reservation: #{reservation}"
      GC.start
    end
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
    LogScanWorker.perform_async(reservation_id)
  end

end
