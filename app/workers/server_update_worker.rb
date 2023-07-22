# frozen_string_literal: true

class ServerUpdateWorker
  include Sidekiq::Worker
  sidekiq_options retry: false
  attr_accessor :latest_version

  MAX_CONCURRENT_UPDATES_PER_IP = 2

  def perform(latest_version)
    @latest_version = latest_version

    ips_with_outdated_servers.each do |ip|
      attempt_upgrade(ip)
    end
  end

  def attempt_upgrade(ip)
    currently_upgrading_count = currently_updating.where(ip: ip).size
    return unless currently_upgrading_count < MAX_CONCURRENT_UPDATES_PER_IP

    to_upgrade_count = MAX_CONCURRENT_UPDATES_PER_IP - currently_upgrading_count

    outdated_servers.where(ip: ip).where(update_status: nil).or(outdated_servers.where(ip: ip).where.not(update_status: 'Updating')).all.sample(to_upgrade_count).each do |s|
      next if s.current_reservation

      Rails.logger.info("Server #{s.name} was found to be outdated, restarting to update")

      s.update_columns(update_status: 'Updating', update_started_at: Time.current)
      s.restart
    end
  end

  def ips_with_outdated_servers
    outdated_servers.group(:ip).pluck(:ip)
  end

  def outdated_servers
    Server.active.outdated(latest_version).where.not(id: reserved_server_ids)
  end

  def currently_updating
    outdated_servers.where(update_status: 'Updating')
  end

  def reserved_server_ids
    @reserved_server_ids ||= Reservation.current.pluck(:server_id)
  end
end
