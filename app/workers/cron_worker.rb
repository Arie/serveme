# typed: true
# frozen_string_literal: true

class CronWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "priority"

  def perform
    end_past_reservations
    start_active_reservations
    check_active_reservations
    check_inactive_servers
    update_servers_page
  end

  def end_past_reservations
    unended_past_normal_reservations.map(&:end_reservation)
  end

  def unended_past_normal_reservations
    unended_past_reservations.where(end_instantly: false)
  end

  def unended_past_reservations
    Reservation.where(ends_at: ...Time.current).where(provisioned: true, ended: false)
  end

  def start_active_reservations
    unstarted_now_reservations = now_reservations.where(provisioned: false, start_instantly: false)
    start_reservations(unstarted_now_reservations)
  end

  def now_reservations
    Reservation.current
  end

  def start_reservations(reservations)
    reservations.map(&:start_reservation)
  end

  def check_active_reservations
    unended_now_reservations      = now_reservations.where(ended: false)
    provisioned_now_reservations  = unended_now_reservations.where(provisioned: true)
    ActiveReservationsCheckerWorker.perform_async(provisioned_now_reservations.pluck(:id))
  end

  def check_inactive_servers
    inactive_servers = Server.active.where.not(id: now_reservations.pluck(:server_id))
    InactiveServersCheckerWorker.perform_async(inactive_servers.pluck(:id))
  end

  def update_servers_page
    UpdateServerPageWorker.perform_in(5.seconds)
  end
end
