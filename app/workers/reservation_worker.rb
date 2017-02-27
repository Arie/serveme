# frozen_string_literal: true
class ReservationWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 3

  attr_accessor :reservation, :reservation_id

  def perform(reservation_id, action)
    @reservation_id = reservation_id
    @reservation = Reservation.includes(:server).find(reservation_id)
    begin
      $lock.synchronize("server-#{reservation.server_id}", retries: 7, initial_wait: 0.5, expiry: 2.minutes) do
        reservation.server.send("#{action}_reservation", reservation)
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
    UpdateSteamNicknameWorker.perform_async(reservation.user.uid)
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
