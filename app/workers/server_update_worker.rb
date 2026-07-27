# typed: true
# frozen_string_literal: true

class ServerUpdateWorker
  include Sidekiq::Worker
  sidekiq_options retry: false
  attr_accessor :latest_version

  MAX_CONCURRENT_UPDATES_PER_IP = 2

  STALE_UPDATE_TIMEOUT = 30.minutes

  def perform(latest_version)
    @latest_version = latest_version

    ips_with_outdated_servers.shuffle.each do |ip|
      attempt_update(ip)
    end
  end

  def attempt_update(ip)
    currently_updating_count = currently_updating.where(ip: ip).count
    return unless currently_updating_count < MAX_CONCURRENT_UPDATES_PER_IP

    to_upgrade_count = MAX_CONCURRENT_UPDATES_PER_IP - currently_updating_count

    updatable(ip).first(to_upgrade_count).each do |s|
      next if s.current_reservation

      if s.update_status == "Updating"
        Rails.logger.warn("Server #{s.name} has been Updating since #{s.update_started_at || 'unknown'}, assuming it failed and retrying")
      else
        Rails.logger.info("Server #{s.name} was found to be outdated, restarting to update")
      end

      s.update_columns(update_status: "Updating", update_started_at: Time.current)
      s.restart
    end
  end

  def updatable(ip)
    not_updating(ip).all.shuffle + stale_updating(ip).all.shuffle
  end

  def not_updating(ip)
    scope = outdated_servers.where(ip: ip)

    scope.where(update_status: nil).or(scope.where.not(update_status: "Updating"))
  end

  def stale_updating(ip)
    outdated_servers.where(ip: ip, update_status: "Updating").where(stale_update_condition)
  end

  def ips_with_outdated_servers
    outdated_servers.group(:ip).pluck(:ip)
  end

  def outdated_servers
    Server.active.outdated(latest_version).where.not(id: reserved_server_ids)
  end

  def currently_updating
    outdated_servers.where(update_status: "Updating").where.not(stale_update_condition)
  end

  def stale_update_condition
    Server.sanitize_sql_array([ "servers.update_started_at IS NULL OR servers.update_started_at < ?", STALE_UPDATE_TIMEOUT.ago ])
  end

  def reserved_server_ids
    @reserved_server_ids ||= Reservation.current.pluck(:server_id)
  end
end
