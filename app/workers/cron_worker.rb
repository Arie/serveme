# frozen_string_literal: true

class CronWorker
  include Sidekiq::Worker

  def perform
    end_past_reservations
    latest_version = Server.fetch_latest_version
    Rails.cache.write('latest_server_version', latest_version) if latest_version
    start_active_reservations
    check_active_reservations
  end

  def end_past_reservations
    unended_past_normal_reservations.map(&:end_reservation)
  end

  def unended_past_normal_reservations
    unended_past_reservations.where('end_instantly = ?', false)
  end

  def unended_past_reservations
    Reservation.where('ends_at < ? AND provisioned = ? AND ended = ?', Time.current, true, false)
  end

  def start_active_reservations
    unstarted_now_reservations = now_reservations.where('provisioned = ? AND start_instantly = ?', false, false)
    start_reservations(unstarted_now_reservations)
  end

  def now_reservations
    Reservation.current
  end

  def start_reservations(reservations)
    reservations.map(&:start_reservation)
  end

  def check_active_reservations
    unended_now_reservations      = now_reservations.where('ended = ?', false)
    provisioned_now_reservations  = unended_now_reservations.where('provisioned = ?', true)
    ActiveReservationsCheckerWorker.perform_async(provisioned_now_reservations.pluck(:id))
  end
end
